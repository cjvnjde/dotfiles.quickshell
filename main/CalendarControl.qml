import QtQuick
import Quickshell

Rectangle {
    id: root

    property int displayedYear: clock.date.getFullYear()
    property int displayedMonth: clock.date.getMonth()

    function changeMonth(offset) {
        const target = new Date(displayedYear, displayedMonth + offset, 1);
        displayedYear = target.getFullYear();
        displayedMonth = target.getMonth();
    }

    function resetToToday() {
        displayedYear = clock.date.getFullYear();
        displayedMonth = clock.date.getMonth();
    }

    function calendarDays() {
        const firstDay = new Date(displayedYear, displayedMonth, 1);
        const mondayOffset = (firstDay.getDay() + 6) % 7;
        const gridStart = new Date(displayedYear, displayedMonth, 1 - mondayOffset);
        const days = [];

        for (let index = 0; index < 42; index++) {
            const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index);
            days.push({
                day: date.getDate(),
                month: date.getMonth(),
                year: date.getFullYear()
            });
        }

        return days;
    }

    width: clockLabel.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: clockMouse.containsMouse ? Theme.surface1 : Theme.surface0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "hh:mm AP")
        color: Theme.blue
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (!calendarPopup.visible) {
                root.resetToToday();
            }
            calendarPopup.visible = !calendarPopup.visible;
        }
    }

    PopupWindow {
        id: calendarPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        width: 322
        height: 330
        color: "transparent"
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            Text {
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 16
                }
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: Theme.text
                font.bold: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
            }

            Text {
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 16
                    rightMargin: 16
                }
                text: Qt.formatDateTime(clock.date, "yyyy")
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 46
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 1
                color: Theme.surface1
            }

            Text {
                id: previousMonth
                anchors {
                    top: parent.top
                    left: parent.left
                    topMargin: 59
                    leftMargin: 18
                }
                text: "󰅁"
                color: previousMouse.containsMouse ? Theme.blue : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3

                MouseArea {
                    id: previousMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    onClicked: root.changeMonth(-1)
                }
            }

            Text {
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 58
                }
                text: Qt.formatDateTime(new Date(root.displayedYear, root.displayedMonth, 1), "MMMM yyyy")
                color: Theme.lavender
                font.bold: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.resetToToday()
                }
            }

            Text {
                id: nextMonth
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 59
                    rightMargin: 18
                }
                text: "󰅂"
                color: nextMouse.containsMouse ? Theme.blue : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    onClicked: root.changeMonth(1)
                }
            }

            Grid {
                id: weekdayGrid
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 92
                    leftMargin: 14
                    rightMargin: 14
                }
                columns: 7

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                    Text {
                        required property string modelData

                        width: weekdayGrid.width / 7
                        height: 24
                        text: modelData
                        color: Theme.subtext0
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }

            Grid {
                id: dayGrid
                anchors {
                    top: weekdayGrid.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 14
                    rightMargin: 14
                    bottomMargin: 12
                }
                columns: 7
                rows: 6

                Repeater {
                    model: root.calendarDays()

                    Rectangle {
                        required property var modelData

                        readonly property bool isToday: modelData.day === clock.date.getDate()
                            && modelData.month === clock.date.getMonth()
                            && modelData.year === clock.date.getFullYear()
                        readonly property bool inDisplayedMonth: modelData.month === root.displayedMonth

                        width: dayGrid.width / 7
                        height: dayGrid.height / 6
                        radius: Math.min(width, height) / 2
                        color: isToday ? Theme.blue : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: parent.isToday
                                ? Theme.base
                                : parent.inDisplayedMonth ? Theme.text : Theme.overlay0
                            font.bold: parent.isToday
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }
        }
    }
}
