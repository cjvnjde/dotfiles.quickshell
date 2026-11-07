import Quickshell

ShellRoot {
    // One wallpaper and one bar per monitor
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher {}
}
