import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: artifact

    required property var controller
    required property string relativePath
    required property string sizeText
    required property string mimeType

    width: 276
    height: 62
    radius: 12
    color: "#202020"
    border.width: 1
    border.color: "#343434"

    RowLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 8
            color: "#303030"

            Text {
                anchors.centerIn: parent
                text: "FILE"
                color: "#cfcfcf"
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: artifact.relativePath
                color: "#ededed"
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: artifact.sizeText + " · " + artifact.mimeType
                color: "#858585"
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 28
            radius: 8
            color: saveMouse.containsMouse && enabled ? "#dedede" : "#bcbcbc"
            opacity: enabled ? 1 : 0.38
            enabled: artifact.controller.canSaveArtifacts

            Text {
                anchors.centerIn: parent
                text: artifact.controller.artifactSaveBusy ? "…" : "Save"
                color: "#171717"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: saveMouse
                anchors.fill: parent
                enabled: parent.enabled
                hoverEnabled: true
                onClicked: artifact.controller.saveArtifact(artifact.relativePath)
            }
        }
    }
}
