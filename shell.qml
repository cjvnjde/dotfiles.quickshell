//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import Quickshell

ShellRoot {
    PrivacyState { id: privacyState }
    // One wallpaper and one bar per monitor
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar { privacy: privacyState }
    }

    Launcher {}
}
