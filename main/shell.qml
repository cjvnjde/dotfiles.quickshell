import QtQuick
import Quickshell
import "topbar"
import "notifications"
import "ai-chat"

ShellRoot {
    NotificationOverlay {
        id: notificationCenter
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        TopBar {
            required property var modelData
            screen: modelData
            aiController: aiChat
            notificationController: notificationCenter
        }
    }

    AppLauncher {}

    AiChat {
        id: aiChat
    }
}
