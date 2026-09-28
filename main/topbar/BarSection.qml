import QtQuick
import ".."
Row {
    id: root
    required property var bar
    required property var entries
    required property string section
    property bool revealed: false
    property string anchorId: ""
    property var loadErrors: ({})
    spacing: 0
    // This is reactive to every slot's animated width, keeping the chosen
    // anchor stationary while neighbors open, close, or change text.
    readonly property real anchorCenter: {
        let offset = 0;
        for (let i = 0; i < repeater.count; i++) {
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            if (slot.modelData.id === anchorId) return offset + Math.max(0, slot.width - Theme.barItemGap) / 2;
            offset += slot.width;
        }
        return width / 2;
    }
    function geometry() {
        const result = [];
        for (let i = 0; i < repeater.count; i++) {
            const slot = repeater.itemAt(i);
            if (slot) result.push({id: slot.modelData.id, x: root.x + slot.x, width: slot.width, loaded: slot.loaderStatus === Loader.Ready});
        }
        return result;
    }
    Repeater {
        id: repeater
        model: root.entries
        Item {
            id: slot
            required property var modelData
            readonly property int loaderStatus: loader.status
            readonly property bool available: !!loader.item && loader.item.available !== false && loader.item.implicitWidth > 0
            readonly property bool shown: available && (modelData.reveal !== "hover" || root.revealed || loader.item.active === true)
            width: shown ? loader.item.implicitWidth + Theme.barItemGap : 0
            height: root.height
            clip: true
            opacity: shown ? 1 : 0
            Behavior on width { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
            Loader {
                id: loader
                width: item ? item.implicitWidth : 0
                height: slot.height
                visible: slot.width > 0
                Component.onCompleted: setSource(Qt.resolvedUrl("../modules/" + slot.modelData.id + "/Widget.qml"), {
                    bar: root.bar,
                    settings: Object.assign({section: root.section}, slot.modelData.settings)
                })
                onStatusChanged: {
                    const errors = Object.assign({}, root.loadErrors);
                    if (status === Loader.Error) errors[slot.modelData.id] = "Could not load modules/" + slot.modelData.id + "/Widget.qml";
                    else delete errors[slot.modelData.id];
                    root.loadErrors = errors;
                }
                Component.onDestruction: {
                    const errors = Object.assign({}, root.loadErrors);
                    delete errors[slot.modelData.id]; root.loadErrors = errors;
                }
            }
        }
    }
}
