import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    Workspaces { id: control; height: root.height; screen: root.bar ? root.bar.screen : null; persistentWorkspaceIds: root.settings.persistent || [1, 2, 3, 4, 5]; width: implicitWidth }
}
