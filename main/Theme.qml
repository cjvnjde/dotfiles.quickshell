pragma Singleton

import QtQuick

QtObject {
    readonly property bool dark: SystemTheme.dark
    readonly property color base: dark ? "#1e1e2e" : "#eff1f5"
    readonly property color mantle: dark ? "#181825" : "#e6e9ef"
    readonly property color crust: dark ? "#11111b" : "#dce0e8"
    readonly property color surface0: dark ? "#313244" : "#ccd0da"
    readonly property color surface1: dark ? "#45475a" : "#bcc0cc"
    readonly property color surface2: dark ? "#585b70" : "#acb0be"
    readonly property color text: dark ? "#cdd6f4" : "#4c4f69"
    readonly property color subtext0: dark ? "#a6adc8" : "#6c6f85"
    readonly property color overlay0: dark ? "#6c7086" : "#9ca0b0"
    readonly property color blue: dark ? "#89b4fa" : "#1e66f5"
    readonly property color lavender: dark ? "#b4befe" : "#7287fd"
    readonly property color sky: dark ? "#89dceb" : "#04a5e5"
    readonly property color green: dark ? "#a6e3a1" : "#40a02b"
    readonly property color yellow: dark ? "#f9e2af" : "#df8e1d"
    readonly property color red: dark ? "#f38ba8" : "#d20f39"
    readonly property color peach: dark ? "#fab387" : "#fe640b"
    readonly property color mauve: dark ? "#cba6f7" : "#8839ef"

    readonly property int fontCaption: 10
    readonly property int fontTitle: 14
    readonly property int fontLarge: 16
    readonly property int fontIcon: 18
    readonly property int fontDisplay: 26
    readonly property int fontHero: 30
    readonly property int fontWeatherIcon: 40
    readonly property string notificationFontFamily: "Liberation Sans"
    readonly property int inputHeight: 36
    readonly property int inputPadding: 12
    readonly property int inputRadius: 5
    readonly property int buttonRadius: 5
    readonly property int panelPadding: 16
    readonly property int panelRadius: 8
    readonly property int barMargin: 10
    readonly property int barItemGap: 3
    readonly property int hoverDelay: 280
    readonly property int animationDuration: 160
    readonly property int barHeight: 32
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
