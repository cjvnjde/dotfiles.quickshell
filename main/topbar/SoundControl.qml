import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "AudioModel.js" as AudioModel
import ".."

Rectangle {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
    readonly property var linkGroups: Pipewire.linkGroups ? Pipewire.linkGroups.values : []

    readonly property var candidateSinks: {
        const values = [];
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (node && node.isSink && !node.isStream) {
                values.push(node);
            }
        }
        return values;
    }

    readonly property var candidateSources: {
        const values = [];
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (node && !node.isSink && !node.isStream && AudioModel.isAudioSource(node)
                    && node.name !== "quickshell") {
                values.push(node);
            }
        }
        return values;
    }

    readonly property var candidateStreams: {
        const values = [];
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (node && AudioModel.isPlaybackStream(node) && node.audio
                    && String(node.name || "").indexOf("omarchy_speaker_tuning") !== 0) {
                values.push(node);
            }
        }
        return values;
    }

    property var displaySinks: []
    property var displaySources: []
    property var displayStreams: []
    property real wheelAccumulator: 0
    property string routeError: ""

    readonly property bool outputAvailable: !!(sink && sink.audio)
    readonly property real outputVolume: outputAvailable ? sink.audio.volume : 0
    readonly property bool outputMuted: outputAvailable && sink.audio.muted
    readonly property bool inputAvailable: !!(source && source.audio)
    readonly property real inputVolume: inputAvailable ? source.audio.volume : 0
    readonly property bool inputMuted: inputAvailable && source.audio.muted
    readonly property bool anyAudible: (outputAvailable && !outputMuted)
        || (inputAvailable && !inputMuted)
    readonly property bool routeAvailable: inputAvailable && outputAvailable
    readonly property bool routeConnected: {
        if (!routeAvailable) {
            return false;
        }

        for (let i = 0; i < linkGroups.length; i++) {
            const link = linkGroups[i];
            if (link && link.source && link.target
                    && link.source.id === source.id
                    && link.target.id === sink.id
                    && link.state === PwLinkState.Active) {
                return true;
            }
        }
        return false;
    }

    function outputIcon() {
        if (!outputAvailable || outputMuted || outputVolume === 0) {
            return "󰝟";
        }
        if (AudioModel.isHeadphones(sink)) {
            return "󰋋";
        }
        if (outputVolume < 0.34) {
            return "󰕿";
        }
        if (outputVolume < 0.67) {
            return "󰖀";
        }
        return "󰕾";
    }

    function setOutputVolume(value) {
        if (outputAvailable) {
            sink.audio.volume = Math.max(0, Math.min(1, value));
        }
    }

    function setInputVolume(value) {
        if (inputAvailable) {
            source.audio.volume = Math.max(0, Math.min(1, value));
        }
    }

    function toggleOutputMute() {
        if (outputAvailable) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function toggleInputMute() {
        if (inputAvailable) {
            source.audio.muted = !source.audio.muted;
        }
    }

    function toggleAllMuted() {
        const mute = anyAudible;
        if (outputAvailable) {
            sink.audio.muted = mute;
        }
        if (inputAvailable) {
            source.audio.muted = mute;
        }
    }

    function setDefaultSink(node) {
        if (node) {
            Pipewire.preferredDefaultAudioSink = node;
        }
    }

    function setDefaultSource(node) {
        if (node) {
            Pipewire.preferredDefaultAudioSource = node;
        }
    }

    function toggleInputMonitor() {
        if (!routeAvailable || routeProcess.running) {
            return;
        }

        routeError = "";
        routeProcess.command = [
            "python3",
            Quickshell.shellPath("topbar/AudioRoute.py"),
            routeConnected ? "disconnect" : "connect",
            String(source.id),
            String(sink.id)
        ];
        routeProcess.running = true;
    }

    function refreshDisplayModels() {
        if (!audioPopup.visible) {
            return;
        }
        // Snapshot away from PipeWire's removal signal; never retain device
        // fallbacks after they disappear from the live graph.
        displaySinks = AudioModel.snapshot(candidateSinks);
        displaySources = AudioModel.snapshot(candidateSources);
        if (sink && displaySinks.indexOf(sink) < 0)
            displaySinks = [sink].concat(displaySinks);
        if (source && displaySources.indexOf(source) < 0)
            displaySources = [source].concat(displaySources);
        displayStreams = AudioModel.snapshot(candidateStreams);
    }

    function scheduleDisplayRefresh() {
        if (audioPopup.visible) {
            audioModelRefresh.restart();
        }
    }

    onCandidateSinksChanged: scheduleDisplayRefresh()
    onCandidateSourcesChanged: scheduleDisplayRefresh()
    onCandidateStreamsChanged: scheduleDisplayRefresh()
    onSinkChanged: scheduleDisplayRefresh()
    onSourceChanged: scheduleDisplayRefresh()

    width: soundRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: soundMouse.containsMouse || audioPopup.visible ? Theme.surface1 : Theme.surface0

    PwObjectTracker {
        objects: root.candidateSinks
    }

    PwObjectTracker {
        objects: root.candidateSources
    }

    PwObjectTracker {
        objects: root.candidateStreams
    }

    PwObjectTracker {
        objects: root.linkGroups
    }

    Process {
        id: routeProcess

        stderr: StdioCollector {
            id: routeProcessError
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                const detail = routeProcessError.text.trim();
                root.routeError = detail || "Could not change the input monitor route";
            }
        }
    }

    Timer {
        id: audioModelRefresh
        interval: 75
        repeat: false
        onTriggered: root.refreshDisplayModels()
    }

    Row {
        id: soundRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.outputIcon()
            color: root.outputMuted ? Theme.red : Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            visible: root.inputAvailable && root.inputMuted
            text: "󰍭"
            color: Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.outputAvailable ? Math.round(root.outputVolume * 100) + "%" : "N/A"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: soundMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.toggleAllMuted();
                return;
            }
            audioPopup.visible = !audioPopup.visible;
        }

        onWheel: wheel => {
            root.wheelAccumulator += wheel.angleDelta.y / 120;
            const steps = root.wheelAccumulator > 0
                ? Math.floor(root.wheelAccumulator)
                : Math.ceil(root.wheelAccumulator);
            if (steps === 0) {
                return;
            }
            root.wheelAccumulator -= steps;
            root.setOutputVolume(root.outputVolume + steps * 0.05);
        }
    }

    PopupWindow {
        id: audioPopup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: Math.min(380, screen ? screen.width - 16 : 380)
        implicitHeight: Math.min(audioColumn.implicitHeight + 28,
            screen ? screen.height - Theme.barHeight - 24 : 660)
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                root.refreshDisplayModels();
                Qt.callLater(() => panel.forceActiveFocus());
            } else {
                audioModelRefresh.stop();
                root.displaySinks = [];
                root.displaySources = [];
                root.displayStreams = [];
            }
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true

            Keys.onEscapePressed: event => {
                audioPopup.visible = false;
                event.accepted = true;
            }

            Flickable {
                id: audioFlick
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: audioColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: audioColumn
                    width: audioFlick.width
                    spacing: 14

                    Column {
                        width: parent.width
                        spacing: 4

                        SectionHeader {
                            title: "OUTPUT"
                            value: root.outputAvailable ? Math.round(root.outputVolume * 100) + "%" : "—"
                            glyph: root.outputIcon()
                            muted: root.outputMuted
                            available: root.outputAvailable
                            hint: root.outputMuted ? "Unmute output" : "Mute output"
                            onToggled: root.toggleOutputMute()
                        }

                        AudioSlider {
                            width: parent.width
                            value: root.outputVolume
                            maximum: 1
                            muted: root.outputMuted
                            enabled: root.outputAvailable
                            onMoved: value => root.setOutputVolume(value)
                            onRightClicked: root.toggleOutputMute()
                        }

                        AudioText {
                            visible: root.displaySinks.length === 0
                            text: "No audio outputs"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Repeater {
                            model: root.displaySinks
                            DeviceRow {
                                required property var modelData
                                width: audioColumn.width
                                node: modelData
                                selected: !!(root.sink && node && root.sink.id === node.id)
                                glyph: AudioModel.sinkIcon(node)
                                onActivated: root.setDefaultSink(node)
                            }
                        }
                    }

                    Divider {}

                    Column {
                        width: parent.width
                        spacing: 4

                        SectionHeader {
                            title: "INPUT"
                            value: root.inputAvailable ? Math.round(root.inputVolume * 100) + "%" : "—"
                            glyph: root.inputMuted ? "󰍭" : "󰍬"
                            muted: root.inputMuted
                            available: root.inputAvailable
                            hint: root.inputMuted ? "Unmute microphone" : "Mute microphone"
                            onToggled: root.toggleInputMute()
                        }

                        AudioSlider {
                            width: parent.width
                            value: root.inputVolume
                            maximum: 1
                            muted: root.inputMuted
                            enabled: root.inputAvailable
                            onMoved: value => root.setInputVolume(value)
                            onRightClicked: root.toggleInputMute()
                        }

                        AudioText {
                            visible: root.displaySources.length === 0
                            text: "No audio inputs"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Repeater {
                            model: root.displaySources
                            DeviceRow {
                                required property var modelData
                                width: audioColumn.width
                                node: modelData
                                selected: !!(root.source && node && root.source.id === node.id)
                                glyph: AudioModel.sourceIcon(node)
                                onActivated: root.setDefaultSource(node)
                            }
                        }

                        Rectangle {
                            visible: root.routeAvailable
                            width: parent.width
                            height: 28
                            radius: Theme.radius
                            color: monitorMouse.containsMouse ? Theme.surface0 : "transparent"

                            AudioText {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Preview microphone"
                                color: Theme.subtext0
                                font.pixelSize: Theme.fontSize - 1
                            }

                            AudioText {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: routeProcess.running ? "…" : root.routeConnected ? "On" : "Off"
                                color: root.routeConnected ? Theme.green : Theme.overlay0
                                font.pixelSize: Theme.fontSize - 1
                            }

                            MouseArea {
                                id: monitorMouse
                                anchors.fill: parent
                                enabled: !routeProcess.running
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleInputMonitor()
                            }

                            AudioTooltip {
                                anchor.item: monitorMouse
                                visible: monitorMouse.containsMouse && audioPopup.visible
                                text: AudioModel.nodeLabel(root.source) + " → " + AudioModel.nodeLabel(root.sink)
                            }
                        }

                        AudioText {
                            visible: root.routeError.length > 0
                            width: parent.width
                            text: root.routeError
                            color: Theme.red
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }

                    Divider {}

                    Column {
                        id: streamsSection
                        width: parent.width
                        spacing: 8

                        AudioText {
                            text: "SOURCES"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 2
                        }

                        AudioText {
                            visible: root.displayStreams.length === 0
                            text: "No playback sources"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Repeater {
                            model: root.displayStreams

                            Column {
                                id: streamRow
                                required property var modelData
                                readonly property bool available: !!(modelData && modelData.audio)
                                readonly property real streamVolume: available ? modelData.audio.volume : 0
                                readonly property bool streamMuted: available && modelData.audio.muted
                                readonly property string label: AudioModel.streamLabel(
                                    modelData, root.mprisPlayers, root.displayStreams)
                                width: streamsSection.width
                                spacing: 0

                                function toggleMuted() {
                                    if (available)
                                        modelData.audio.muted = !modelData.audio.muted;
                                }

                                Item {
                                    width: parent.width
                                    height: 24

                                    MuteButton {
                                        id: streamMute
                                        enabled: streamRow.available
                                        glyph: streamRow.streamMuted ? "󰝟" : "󰕾"
                                        muted: streamRow.streamMuted
                                        hint: (muted ? "Unmute " : "Mute ") + streamRow.label
                                        onToggled: streamRow.toggleMuted()
                                    }

                                    AudioText {
                                        id: streamLabel
                                        anchors.left: streamMute.right
                                        anchors.right: streamPercent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 8
                                        text: streamRow.label
                                        elide: Text.ElideRight

                                        MouseArea {
                                            id: streamLabelMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                        AudioTooltip {
                                            anchor.item: streamLabelMouse
                                            visible: streamLabelMouse.containsMouse && streamLabel.truncated && audioPopup.visible
                                            text: streamRow.label
                                        }
                                    }

                                    AudioText {
                                        id: streamPercent
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(streamRow.streamVolume * 100) + "%"
                                        color: streamRow.streamMuted ? Theme.overlay0 : Theme.subtext0
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                }

                                AudioSlider {
                                    width: parent.width
                                    value: streamRow.streamVolume
                                    maximum: 1.5
                                    muted: streamRow.streamMuted
                                    enabled: streamRow.available
                                    onMoved: value => {
                                        if (streamRow.available)
                                            streamRow.modelData.audio.volume = value;
                                    }
                                    onRightClicked: streamRow.toggleMuted()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component AudioText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        textFormat: Text.PlainText
    }

    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    component AudioTooltip: PopupWindow {
        id: tooltipWindow
        property string text: ""
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: Math.min(tooltip.implicitWidth + 20, screen ? screen.width - 16 : 500)
        implicitHeight: tooltip.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            AudioText {
                id: tooltip
                anchors.centerIn: parent
                width: Math.min(implicitWidth, tooltipWindow.width - 20)
                text: tooltipWindow.text
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }

    component MuteButton: Rectangle {
        id: muteButton
        property string glyph: ""
        property bool muted: false
        property string hint: ""
        signal toggled()
        width: 24
        height: 24
        radius: Theme.radius
        color: muteMouse.containsMouse ? Theme.surface0 : "transparent"
        opacity: enabled ? 1 : 0.35
        Accessible.role: Accessible.Button
        Accessible.name: hint

        AudioText {
            anchors.centerIn: parent
            text: muteButton.glyph
            color: muteButton.muted ? Theme.red : Theme.subtext0
            font.pixelSize: Theme.fontSize + 2
        }

        MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: muteButton.toggled()
        }

        AudioTooltip {
            anchor.item: muteMouse
            visible: muteMouse.containsMouse && audioPopup.visible
            text: muteButton.hint
        }
    }

    component SectionHeader: Item {
        id: header
        required property string title
        property string value: ""
        property string glyph: ""
        property string hint: ""
        property bool muted: false
        property bool available: false
        signal toggled()
        width: parent.width
        height: 24

        AudioText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: header.title
            color: Theme.overlay0
            font.pixelSize: Theme.fontSize - 2
        }

        AudioText {
            anchors.right: headerMute.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: header.value
            color: header.muted ? Theme.overlay0 : Theme.subtext0
            font.pixelSize: Theme.fontSize - 2
        }

        MuteButton {
            id: headerMute
            anchors.right: parent.right
            enabled: header.available
            glyph: header.glyph
            muted: header.muted
            hint: header.hint
            onToggled: header.toggled()
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow
        required property var node
        property bool selected: false
        property string glyph: ""
        signal activated()
        height: 30
        radius: Theme.radius
        color: selected || deviceMouse.containsMouse ? Theme.surface0 : "transparent"

        AudioText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: deviceRow.glyph
            color: deviceRow.selected ? Theme.green : Theme.subtext0
            font.pixelSize: Theme.fontSize + 2
        }

        AudioText {
            id: deviceLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 36
            anchors.rightMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            text: AudioModel.nodeLabel(deviceRow.node)
            elide: Text.ElideRight
        }

        AudioText {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.selected ? "✓" : ""
            color: Theme.green
            font.pixelSize: Theme.fontSize - 1
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            enabled: !!deviceRow.node
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: deviceRow.activated()
        }

        AudioTooltip {
            anchor.item: deviceMouse
            visible: deviceMouse.containsMouse && deviceLabel.truncated && audioPopup.visible
            text: deviceLabel.text
        }
    }

    component AudioSlider: Item {
        id: slider
        required property real value
        required property real maximum
        property bool muted: false
        signal moved(real value)
        signal rightClicked()
        implicitHeight: 20
        opacity: enabled ? (muted ? 0.5 : 1) : 0.35

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: height / 2
            color: Theme.surface0

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slider.value / slider.maximum))
                height: parent.height
                radius: height / 2
                color: slider.muted ? Theme.overlay0 : Theme.green
            }

            Rectangle {
                visible: sliderMouse.containsMouse || sliderMouse.pressed
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * slider.value / slider.maximum - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: width / 2
                color: Theme.text
            }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: pressed

            function updateValue(mouseX) {
                slider.moved(Math.max(0, Math.min(1, mouseX / width)) * slider.maximum);
            }

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton)
                    slider.rightClicked();
                else
                    updateValue(mouse.x);
            }
            onPositionChanged: mouse => {
                if (pressed && (pressedButtons & Qt.LeftButton))
                    updateValue(mouse.x);
            }
        }
    }
}
