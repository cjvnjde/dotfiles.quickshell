import QtQuick
import Quickshell
import "topbar"
import "notifications"
import "ai-chat"
import "notes"

ShellRoot {
    Notes {
        id: notes
    }

    Variants {
        model: Quickshell.screens

        TopBar {
            required property var modelData
            screen: modelData
            notesController: notes
            aiController: aiChat
        }
    }

    NotificationOverlay {}

    AppLauncher {}

    AiChat {
        id: aiChat
    }
}
