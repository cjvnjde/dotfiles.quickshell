import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: viewer

    property string source: ""
    property string title: ""
    property real zoom: 1
    readonly property real fitScale: Math.min(1, viewport.width / Math.max(1, image.implicitWidth),
        viewport.height / Math.max(1, image.implicitHeight))
    readonly property real maximumZoom: Math.max(8, 1 / Math.max(0.001, fitScale))
    signal closed()

    visible: source.length > 0
    color: "#e6101116"
    focus: visible

    function open(imageSource, imageTitle) {
        title = imageTitle || "Image";
        zoom = 1;
        source = imageSource;
        forceActiveFocus();
        resetPosition();
    }

    function close() {
        if (!visible) return;
        source = "";
        title = "";
        closed();
    }

    function resetPosition() {
        viewport.contentX = Math.max(0, (viewport.contentWidth - viewport.width) / 2);
        viewport.contentY = Math.max(0, (viewport.contentHeight - viewport.height) / 2);
    }

    function setZoom(value, x, y) {
        const oldWidth = viewport.contentWidth;
        const oldHeight = viewport.contentHeight;
        const relativeX = (viewport.contentX + x) / Math.max(1, oldWidth);
        const relativeY = (viewport.contentY + y) / Math.max(1, oldHeight);
        zoom = Math.max(1, Math.min(maximumZoom, value));
        viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width,
            relativeX * viewport.contentWidth - x));
        viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height,
            relativeY * viewport.contentHeight - y));
    }

    onWidthChanged: { zoom = 1; resetPosition(); }
    onHeightChanged: { zoom = 1; resetPosition(); }
    Keys.onEscapePressed: event => { close(); event.accepted = true; }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            setZoom(zoom * 1.25, viewport.width / 2, viewport.height / 2);
        } else if (event.key === Qt.Key_Minus) {
            setZoom(zoom / 1.25, viewport.width / 2, viewport.height / 2);
        } else if (event.key === Qt.Key_0) {
            setZoom(1, viewport.width / 2, viewport.height / 2);
        } else {
            return;
        }
        event.accepted = true;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: viewer.close()
        onWheel: wheel => wheel.accepted = true
    }

    Flickable {
        id: viewport
        anchors { fill: parent; leftMargin: 32; rightMargin: 32; topMargin: 88; bottomMargin: 56 }
        clip: true
        contentWidth: Math.max(width, image.width)
        contentHeight: Math.max(height, image.height)
        boundsBehavior: Flickable.StopAtBounds
        interactive: viewer.zoom > 1

        Image {
            id: image
            x: Math.max(0, (viewport.width - width) / 2)
            y: Math.max(0, (viewport.height - height) / 2)
            width: implicitWidth * viewer.fitScale * viewer.zoom
            height: implicitHeight * viewer.fitScale * viewer.zoom
            source: viewer.source
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Ready) viewer.resetPosition()

            MouseArea {
                anchors.fill: parent
                cursorShape: viewer.zoom > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    : Qt.PointingHandCursor
                onClicked: mouse => mouse.accepted = true
                onDoubleClicked: mouse => viewer.setZoom(viewer.zoom > 1 ? 1 : 2,
                    mouse.x + image.x - viewport.contentX, mouse.y + image.y - viewport.contentY)
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y || wheel.pixelDelta.y;
                    if (delta !== 0) {
                        viewer.setZoom(viewer.zoom * (delta > 0 ? 1.2 : 1 / 1.2),
                            wheel.x + image.x - viewport.contentX,
                            wheel.y + image.y - viewport.contentY);
                    }
                    wheel.accepted = true;
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: image.status === Image.Error ? "Could not decode image." : "Loading image…"
        color: "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        height: 52
        radius: 12
        color: AiChatTheme.background
        // The toolbar is not part of the dismissible backdrop.
        MouseArea { anchors.fill: parent }
        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: viewer.title
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: AiChatTheme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
            Repeater {
                model: ["−", "+", "Fit", "100%", "Close"]
                Rectangle {
                    required property string modelData
                    implicitWidth: label.implicitWidth + 18
                    implicitHeight: 32
                    radius: 9
                    color: buttonMouse.containsMouse ? AiChatTheme.hover : AiChatTheme.surface
                    enabled: modelData === "Close" || image.status === Image.Ready
                    opacity: enabled ? 1 : 0.4
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData
                        color: AiChatTheme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: buttonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData === "Close") { viewer.close(); return; }
                            const nextZoom = modelData === "Fit" ? 1
                                : modelData === "100%" ? 1 / viewer.fitScale
                                : viewer.zoom * (modelData === "+" ? 1.25 : 1 / 1.25);
                            viewer.setZoom(nextZoom, viewport.width / 2, viewport.height / 2);
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 14 }
        width: parent.width - 32
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "Scroll to zoom · Drag to pan · Double-click to toggle zoom · Esc to close"
        color: "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
