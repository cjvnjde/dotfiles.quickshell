import QtQuick
import Quickshell

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
}
