import QtQuick
import ".."
// Minimal contract for your own widgets. Set active to stay visible when folded.
Item {
    property var bar: null
    property var settings: ({})
    property bool active: false
    property bool available: true
    implicitWidth: 30
    implicitHeight: Theme.barHeight
}
