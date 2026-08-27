pragma Singleton

import QtQuick

QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay0: "#6c7086"
    readonly property color blue: "#89b4fa"
    readonly property color lavender: "#b4befe"
    readonly property color sky: "#89dceb"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color mauve: "#cba6f7"

    readonly property int barHeight: 24
    readonly property int barInset: 1
    readonly property int barTopInset: 2
    readonly property int barBottomInset: 1
    readonly property int controlHorizontalPadding: 6
    readonly property int notificationMargin: 6
    readonly property int radius: 10
    readonly property int spacing: 6
    readonly property int fontSize: 12
    readonly property string fontFamily: "FiraCode Nerd Font"
}
