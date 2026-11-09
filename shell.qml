//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import Quickshell

ShellRoot {
    PrivacyState { id: privacyState }
    Scope {
        id: keepAwakeState
        property bool enabled: false
    }
    // One wallpaper and one bar per monitor
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar { privacy: privacyState; keepAwake: keepAwakeState }
    }

    Launcher {}
}
