import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: artifact

    required property var controller
    required property string relativePath
    required property string sizeText
    required property string mimeType

    width: 310
    height: 62
    radius: 12
    color: AiChatTheme.surface
    border.width: 1
    border.color: AiChatTheme.border

    RowLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 8
            color: AiChatTheme.raised

            Text {
                anchors.centerIn: parent
                text: "FILE"
                color: AiChatTheme.text
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
                color: AiChatTheme.text
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: artifact.sizeText + " · " + artifact.mimeType
                color: AiChatTheme.mutedText
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 28
            radius: 8
            color: saveMouse.containsMouse && enabled ? AiChatTheme.actionHover : AiChatTheme.action
            opacity: enabled ? 1 : 0.38
            enabled: artifact.controller.canSaveArtifacts

            Text {
                anchors.centerIn: parent
                text: artifact.controller.artifactSaveBusy ? "…" : "Save"
                color: AiChatTheme.actionText
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

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            color: deleteMouse.containsMouse && enabled ? AiChatTheme.hover : AiChatTheme.raised
            opacity: enabled ? 1 : 0.38
            enabled: artifact.controller.canDeleteArtifacts

            Text {
                anchors.centerIn: parent
                text: artifact.controller.artifactDeleteBusy
                        && artifact.controller.artifactDeletePath
                            === artifact.relativePath ? "…" : "×"
                color: AiChatTheme.error
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }

            MouseArea {
                id: deleteMouse
                anchors.fill: parent
                enabled: parent.enabled
                hoverEnabled: true
                onClicked: artifact.controller.deleteArtifact(
                    artifact.relativePath)
            }
        }
    }
}
