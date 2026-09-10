import QtQuick
import Quickshell
import "topbar"
import "notifications"
import "ai-chat"

ShellRoot {

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
        }
    }

    NotificationOverlay {}

    AppLauncher {}

    AiChat {
        id: aiChat
    }
}
