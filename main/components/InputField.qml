import QtQuick
import QtQuick.Controls
import ".."
TextField {
    id: root
    implicitHeight: Theme.inputHeight
    leftPadding: Theme.inputPadding
    rightPadding: Theme.inputPadding
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontTitle
    color: Theme.text
    placeholderTextColor: Theme.overlay0
    selectionColor: Theme.blue
    selectedTextColor: Theme.base
    selectByMouse: true
    clip: true
    background: Rectangle {
        radius: Theme.inputRadius
        color: Theme.surface0
        border.width: 1
        border.color: root.activeFocus ? Theme.blue : Theme.surface1
    }
}
