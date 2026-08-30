import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "AudioModel.js" as AudioModel

Rectangle {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []

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

    readonly property bool outputAvailable: sink !== null && sink.audio !== null
    readonly property real outputVolume: outputAvailable ? sink.audio.volume : 0
    readonly property bool outputMuted: outputAvailable && sink.audio.muted
    readonly property bool inputAvailable: source !== null && source.audio !== null
    readonly property real inputVolume: inputAvailable ? source.audio.volume : 0
    readonly property bool inputMuted: inputAvailable && source.audio.muted
    readonly property bool anyAudible: (outputAvailable && !outputMuted)
        || (inputAvailable && !inputMuted)

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

    function refreshDisplayModels() {
        if (!audioPopup.visible) {
            return;
        }
        displaySinks = AudioModel.snapshot(candidateSinks);
        displaySources = AudioModel.snapshot(candidateSources);
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

    width: soundRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: soundMouse.containsMouse ? Theme.surface1 : Theme.surface0

    PwObjectTracker {
        objects: root.candidateSinks
    }

    PwObjectTracker {
        objects: root.candidateSources
    }

    PwObjectTracker {
        objects: root.candidateStreams
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
        width: 360
        height: Math.min(560, Math.max(180, audioColumn.implicitHeight + 28))
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                root.refreshDisplayModels();
            } else {
                audioModelRefresh.stop();
                root.displaySinks = [];
                root.displaySources = [];
                root.displayStreams = [];
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

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
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 36

                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            text: "Audio"
                            color: Theme.text
                            font.bold: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 2
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            width: 72
                            height: 26
                            radius: height / 2
                            color: root.anyAudible ? Theme.green : Theme.surface1

                            Text {
                                anchors.centerIn: parent
                                text: root.anyAudible ? "On" : "Muted"
                                color: root.anyAudible ? Theme.base : Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.toggleAllMuted()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.surface1
                    }

                    SectionHeader {
                        title: "OUTPUT"
                        value: root.outputAvailable ? Math.round(root.outputVolume * 100) + "%" : "N/A"
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

                    Text {
                        visible: root.displaySinks.length === 0
                        text: "No audio outputs"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: root.displaySinks

                        Rectangle {
                            id: sinkRow
                            required property var modelData
                            required property int index

                            readonly property bool active: root.sink
                                && modelData && root.sink.id === modelData.id

                            width: audioColumn.width
                            height: 34
                            radius: Theme.radius
                            color: active
                                ? Theme.surface1
                                : sinkMouse.containsMouse ? Theme.surface0 : "transparent"

                            Text {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 8
                                }
                                width: 22
                                text: AudioModel.sinkIcon(sinkRow.modelData)
                                color: sinkRow.active ? Theme.green : Theme.text
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 38
                                    rightMargin: 8
                                }
                                text: AudioModel.nodeLabel(sinkRow.modelData)
                                color: Theme.text
                                elide: Text.ElideRight
                                font.bold: sinkRow.active
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            MouseArea {
                                id: sinkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.setDefaultSink(sinkRow.modelData)
                            }
                        }
                    }

                    Rectangle {
                        visible: inputSection.visible
                        width: parent.width
                        height: visible ? 1 : 0
                        color: Theme.surface1
                    }

                    Column {
                        id: inputSection
                        visible: root.inputAvailable || root.displaySources.length > 0
                        width: parent.width
                        spacing: 8

                        SectionHeader {
                            title: "INPUT"
                            value: root.inputAvailable ? Math.round(root.inputVolume * 100) + "%" : "N/A"
                        }

                        AudioSlider {
                            visible: root.inputAvailable
                            width: parent.width
                            value: root.inputVolume
                            maximum: 1
                            muted: root.inputMuted
                            onMoved: value => root.setInputVolume(value)
                            onRightClicked: root.toggleInputMute()
                        }

                        Repeater {
                            model: root.displaySources

                            Rectangle {
                                id: sourceRow
                                required property var modelData
                                required property int index

                                readonly property bool active: root.source
                                    && modelData && root.source.id === modelData.id

                                width: inputSection.width
                                height: 34
                                radius: Theme.radius
                                color: active
                                    ? Theme.surface1
                                    : sourceMouse.containsMouse ? Theme.surface0 : "transparent"

                                Text {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 8
                                    }
                                    width: 22
                                    text: AudioModel.sourceIcon(sourceRow.modelData)
                                    color: sourceRow.active ? Theme.green : Theme.text
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 2
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 38
                                        rightMargin: 8
                                    }
                                    text: AudioModel.nodeLabel(sourceRow.modelData)
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    font.bold: sourceRow.active
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }

                                MouseArea {
                                    id: sourceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.setDefaultSource(sourceRow.modelData)
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: streamsSection.visible
                        width: parent.width
                        height: visible ? 1 : 0
                        color: Theme.surface1
                    }

                    Column {
                        id: streamsSection
                        visible: root.displayStreams.length > 0
                        width: parent.width
                        spacing: 8

                        SectionHeader {
                            title: "APPLICATIONS"
                            value: root.displayStreams.length
                        }

                        Repeater {
                            model: root.displayStreams

                            Column {
                                id: streamRow
                                required property var modelData
                                required property int index

                                readonly property real streamVolume: modelData && modelData.audio
                                    ? modelData.audio.volume : 0
                                readonly property bool streamMuted: modelData && modelData.audio
                                    ? modelData.audio.muted : false

                                width: streamsSection.width
                                spacing: 4

                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        id: streamMuteIcon
                                        anchors {
                                            left: parent.left
                                            verticalCenter: parent.verticalCenter
                                        }
                                        width: 24
                                        text: streamRow.streamMuted ? "󰝟" : "󰕾"
                                        color: streamRow.streamMuted ? Theme.overlay0 : Theme.text
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize + 2

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (streamRow.modelData.audio) {
                                                    streamRow.modelData.audio.muted =
                                                        !streamRow.modelData.audio.muted;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors {
                                            left: streamMuteIcon.right
                                            right: streamPercent.left
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 6
                                            rightMargin: 6
                                        }
                                        text: AudioModel.streamLabel(
                                            streamRow.modelData,
                                            root.mprisPlayers,
                                            root.displayStreams
                                        )
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }

                                    Text {
                                        id: streamPercent
                                        anchors {
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                        }
                                        width: 42
                                        text: Math.round(streamRow.streamVolume * 100) + "%"
                                        color: Theme.subtext0
                                        horizontalAlignment: Text.AlignRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                }

                                AudioSlider {
                                    width: parent.width
                                    value: streamRow.streamVolume
                                    maximum: 1.5
                                    muted: streamRow.streamMuted
                                    onMoved: value => {
                                        if (streamRow.modelData.audio) {
                                            streamRow.modelData.audio.volume = value;
                                        }
                                    }
                                    onRightClicked: {
                                        if (streamRow.modelData.audio) {
                                            streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component SectionHeader: Item {
        required property string title
        property var value: ""

        width: parent.width
        height: 20

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            text: parent.title
            color: Theme.subtext0
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Text {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: parent.value
            color: Theme.subtext0
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    component AudioSlider: Item {
        id: slider

        required property real value
        required property real maximum
        property bool muted: false
        signal moved(real value)
        signal rightClicked

        implicitHeight: 22
        opacity: enabled ? (muted ? 0.5 : 1) : 0.35

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 7
            radius: height / 2
            color: Theme.surface1

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slider.value / slider.maximum))
                height: parent.height
                radius: height / 2
                color: slider.muted ? Theme.overlay0 : Theme.green
            }

            Rectangle {
                x: Math.max(0, Math.min(
                    parent.width - width,
                    parent.width * slider.value / slider.maximum - width / 2
                ))
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: width / 2
                color: Theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            function updateValue(mouseX) {
                slider.moved(Math.max(0, Math.min(1, mouseX / width)) * slider.maximum);
            }

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    slider.rightClicked();
                } else {
                    updateValue(mouse.x);
                }
            }
            onPositionChanged: mouse => {
                if (pressed && pressedButtons & Qt.LeftButton) {
                    updateValue(mouse.x);
                }
            }
        }
    }
}
