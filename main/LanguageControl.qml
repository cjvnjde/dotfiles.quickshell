import QtQuick

Rectangle {
    width: languageText.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: Theme.surface0

    Text {
        id: languageText
        anchors.centerIn: parent
        text: KeyboardLayout.language
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
