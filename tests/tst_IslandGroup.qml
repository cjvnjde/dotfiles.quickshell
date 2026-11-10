import QtQuick
import QtTest
import ".."

TestCase {
    id: tests
    name: "IslandGroup"
    width: 640
    height: 320
    visible: true
    when: windowShown

    Component {
        id: fixtureComponent
        Item {
            width: tests.width
            height: tests.height
            property alias leftDrawer: leftGroup
            property alias rightDrawer: rightGroup
            property alias firstIsland: firstChild
            property alias secondIsland: secondChild

            IslandGroup {
                id: leftGroup
                anchors.right: parent.right
                anchors.rightMargin: 40
                y: 60
                base: "#1e1e2e"
                surface: "#313244"
                foreground: "#cdd6f4"
                lavender: "#b4befe"

                Rectangle {
                    id: firstChild
                    width: 30
                    height: 20
                    color: "#1e1e2e"
                    MouseArea { anchors.fill: parent; hoverEnabled: true }
                }
                Rectangle {
                    id: secondChild
                    width: 40
                    height: 20
                    color: "#1e1e2e"
                    MouseArea { anchors.fill: parent; hoverEnabled: true }
                }
            }

            IslandGroup {
                id: rightGroup
                x: 40
                y: 160
                direction: Qt.RightEdge
                base: "#1e1e2e"
                surface: "#313244"
                foreground: "#cdd6f4"
                lavender: "#b4befe"

                Rectangle { width: 30; height: 20; color: "#1e1e2e" }
            }
        }
    }

    property var fixture

    function init() {
        fixture = createTemporaryObject(fixtureComponent, tests);
        verify(fixture !== null);
        mouseMove(tests, 320, 280);
    }

    function toggleX(group) {
        return group.direction === Qt.LeftEdge ? group.width - 10 : 10;
    }

    function test_hoverAcrossChildrenAndGaps() {
        const group = fixture.leftDrawer;
        mouseMove(group, toggleX(group), 10);
        tryCompare(group, "expanded", true);
        tryCompare(group, "width", 98);
        mouseMove(fixture.firstIsland, 15, 10);
        compare(group.expanded, true);
        mouseMove(fixture.firstIsland, fixture.firstIsland.width + 2, 10);
        compare(group.expanded, true);
        mouseMove(fixture.secondIsland, 20, 10);
        compare(group.expanded, true);
        mouseMove(tests, 320, 280);
        tryCompare(group, "expanded", false);
        tryCompare(group, "width", 20);
    }

    function test_clickPinsAndSecondClickCloses() {
        const group = fixture.leftDrawer;
        mouseMove(group, toggleX(group), 10);
        tryCompare(group, "width", 98);
        mouseClick(group, toggleX(group), 10);
        compare(group.pinned, true);
        mouseMove(tests, 320, 280);
        compare(group.expanded, true);
        mouseMove(group, toggleX(group), 10);
        mouseClick(group, toggleX(group), 10);
        compare(group.pinned, false);
        tryCompare(group, "expanded", false);
        tryCompare(group, "width", 20);
        // Staying on the toggle must not reopen it; leaving and returning should.
        mouseMove(group, toggleX(group), 10);
        compare(group.expanded, false);
        mouseMove(tests, 320, 280);
        mouseMove(group, toggleX(group), 10);
        tryCompare(group, "expanded", true);
    }

    function test_directionKeepsToggleAnchored_data() {
        return [{ tag: "left", side: "leftDrawer" }, { tag: "right", side: "rightDrawer" }];
    }

    function test_directionKeepsToggleAnchored(data) {
        const group = fixture[data.side];
        const before = group.mapToItem(tests, toggleX(group), 10);
        mouseMove(group, toggleX(group), 10);
        tryCompare(group, "expanded", true);
        tryCompare(group, "width", data.side === "leftDrawer" ? 98 : 54);
        const after = group.mapToItem(tests, toggleX(group), 10);
        compare(after.x, before.x);
        compare(after.y, before.y);
        compare(fixture[data.side === "leftDrawer" ? "rightDrawer" : "leftDrawer"].expanded, false);
    }

    function test_popupHoldsGroupUntilDismissed() {
        const group = fixture.leftDrawer;
        mouseMove(group, toggleX(group), 10);
        tryCompare(group, "width", 98);
        group.holdOpen = true;
        mouseMove(tests, 320, 280);
        compare(group.expanded, true);
        group.holdOpen = false;
        tryCompare(group, "expanded", false);
        tryCompare(group, "width", 20);
    }

    function test_hiddenChildrenAndChangingWidth() {
        const group = fixture.leftDrawer;
        group.pinned = true;
        tryCompare(group, "width", 98);
        fixture.firstIsland.visible = false;
        tryCompare(group, "width", 64);
        fixture.secondIsland.width = 60;
        tryCompare(group, "width", 84);
        fixture.secondIsland.visible = false;
        tryCompare(group, "width", 20);
        fixture.firstIsland.visible = true;
        tryCompare(group, "width", 54);
    }
}
