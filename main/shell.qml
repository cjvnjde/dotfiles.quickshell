import QtQuick
import Quickshell
import "topbar"
import "notifications"
import "ai-chat"

ShellRoot {
    Variants {
        model: Quickshell.screens

        TopBar {
            required property var modelData
            screen: modelData
        }
    }

    NotificationOverlay {}

    AppLauncher {}

    AiChat {}
}
