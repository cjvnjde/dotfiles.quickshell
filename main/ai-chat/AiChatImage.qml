import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Rectangle {
    id: root

    required property var controller
    required property string imageUrl
    required property string altText
    required property string threadId
    readonly property string outputDirectory: controller.activeSandboxOutputDirectory
    readonly property bool localImage: imageUrl.length > 0
        && !/^(?:https?:|data:|file:)/i.test(imageUrl)
    property string loadedSource: ""
    property string loadError: ""
    property int requestSerial: 0
    property bool ready: false
    property bool retryOnGenerationEnd: false

    Layout.fillWidth: true
    implicitHeight: preview.status === Image.Ready
        ? Math.max(1, Math.min(360, width * preview.implicitHeight
            / Math.max(1, preview.implicitWidth)))
        : Math.max(100, fallback.implicitHeight + 24)
    radius: 10
    color: AiChatTheme.surface
    clip: true

    function reload() {
        requestSerial++;
        requestLoader.active = false;
        loadedSource = "";
        loadError = "";
        retryOnGenerationEnd = localImage && controller.isGenerating;
        if (ready && imageUrl.length > 0) {
            requestTimer.restart();
        }
    }

    function fail(message) {
        loadedSource = "";
        loadError = message || "Could not load image.";
        if (retryOnGenerationEnd && !controller.isGenerating) {
            reload();
        }
    }

    onImageUrlChanged: reload()
    onThreadIdChanged: reload()
    onOutputDirectoryChanged: reload()
    Component.onCompleted: {
        ready = true;
        reload();
    }

    Connections {
        target: root.controller
        function onIsGeneratingChanged() {
            if (root.controller.isGenerating) {
                if (root.localImage && root.loadedSource.length === 0) {
                    root.retryOnGenerationEnd = true;
                }
            } else if (root.retryOnGenerationEnd && root.loadError.length > 0) {
                root.reload();
            }
        }
    }

    Timer {
        id: requestTimer
        interval: 0
        onTriggered: requestLoader.active = root.imageUrl.length > 0
    }

    // A new Process per request isolates collectors and callbacks when a
    // streaming block changes URL, thread, or sandbox while a load is active.
    Loader {
        id: requestLoader
        active: false
        sourceComponent: Component {
            Process {
                id: request
                property int serial: -1
                property string requestUrl: ""
                property bool started: false
                stdinEnabled: true
                stdout: StdioCollector { id: result }
                stderr: StdioCollector {}
                onStarted: {
                    started = true;
                    write(requestUrl);
                    stdinEnabled = false;
                }
                onRunningChanged: {
                    if (!running && !started && serial === root.requestSerial) {
                        root.fail("Could not start image loader.");
                    }
                }
                onExited: function(exitCode) {
                    if (serial !== root.requestSerial) {
                        return;
                    }
                    let response;
                    try {
                        response = JSON.parse(result.text);
                    } catch (error) {
                        root.fail("Could not read image loader response.");
                        return;
                    }
                    if (exitCode !== 0 || !response.source
                            || !/^data:image\/(?:png|jpeg|gif|webp);base64,/i.test(response.source)) {
                        root.fail(response.error || "Could not load image.");
                        return;
                    }
                    root.loadError = "";
                    root.loadedSource = response.source;
                }
            }
        }
        onLoaded: {
            item.serial = root.requestSerial;
            item.requestUrl = root.imageUrl;
            item.command = [
                "python3", Quickshell.shellPath("ai-chat/AiChatImage.py"),
                root.outputDirectory, root.threadId
            ];
            item.running = true;
        }
    }

    Image {
        id: preview
        anchors.fill: parent
        source: root.loadedSource
        asynchronous: true
        cache: false
        sourceSize.width: 1600
        sourceSize.height: 1600
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error && root.loadedSource.length > 0) {
                root.fail("Could not decode image.");
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: preview.status === Image.Ready
            cursorShape: Qt.PointingHandCursor
            onClicked: root.controller.imagePreviewRequested(root.loadedSource, root.altText)
        }
    }

    ColumnLayout {
        id: fallback
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 24)
        visible: preview.status !== Image.Ready
        spacing: 8

        Text {
            Layout.fillWidth: true
            visible: root.altText.length > 0
            text: root.altText
            textFormat: Text.PlainText
            color: AiChatTheme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.loadError || "Loading image…"
            textFormat: Text.PlainText
            color: AiChatTheme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.preferredWidth: retryLabel.implicitWidth + 24
            Layout.preferredHeight: 28
            visible: root.loadError.length > 0
            radius: 7
            color: retryMouse.containsMouse ? AiChatTheme.actionHover : AiChatTheme.action
            Text {
                id: retryLabel
                anchors.centerIn: parent
                text: "Retry image"
                color: AiChatTheme.actionText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            MouseArea {
                id: retryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reload()
            }
        }
    }
}
