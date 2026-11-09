pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell

PopupWindow {
    id: popup
    required property Item target
    anchor.item: target
    anchor.rect.y: target.height + 4
    anchor.rect.x: target.width - width
    required property date today
    signal dismissed()
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    property date selectedDate: today
    readonly property int firstWeekday: (month.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
    implicitWidth: 248
    implicitHeight: calendarContent.implicitHeight + 24
    color: "transparent"
    grabFocus: true

    function moveMonth(delta) {
        month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
    }
    function reset() {
        month = new Date(today.getFullYear(), today.getMonth(), 1);
        selectedDate = new Date(today);
    }
    // Native popup grabs dismiss on outside clicks. Reflect compositor-driven
    // closure back to the clock's open state as well as explicit dismissal.
    onVisibleChanged: {
        if (visible) reset();
        else dismissed();
    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 5
        border.color: "#313244"
        border.width: 1
        focus: true
        Keys.onEscapePressed: popup.dismissed()

        Column {
            id: calendarContent
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            spacing: 6
            Row {
                width: 224
                spacing: 4
                Button {
                    id: previousMonth
                    width: 24; height: 24
                    padding: 0
                    topInset: 0; bottomInset: 0
                    leftInset: 0; rightInset: 0
                    background: Rectangle {
                        radius: 3
                        color: previousMonth.hovered ? "#313244" : "transparent"
                    }
                    contentItem: Item {
                        Canvas {
                            anchors.centerIn: parent
                            width: 8; height: 12
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = "#b4befe";
                                ctx.lineWidth = 1.5;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath();
                                ctx.moveTo(6, 2);
                                ctx.lineTo(2, 6);
                                ctx.lineTo(6, 10);
                                ctx.stroke();
                            }
                        }
                    }
                    onClicked: popup.moveMonth(-1)
                }
                Text {
                    width: 168; height: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.formatDateTime(popup.month, "MMMM yyyy")
                    color: "#cdd6f4"
                    font { family: "sans-serif"; pixelSize: 12; weight: Font.DemiBold }
                }
                Button {
                    id: nextMonth
                    width: 24; height: 24
                    padding: 0
                    topInset: 0; bottomInset: 0
                    leftInset: 0; rightInset: 0
                    background: Rectangle {
                        radius: 3
                        color: nextMonth.hovered ? "#313244" : "transparent"
                    }
                    contentItem: Item {
                        Canvas {
                            anchors.centerIn: parent
                            width: 8; height: 12
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = "#b4befe";
                                ctx.lineWidth = 1.5;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath();
                                ctx.moveTo(2, 2);
                                ctx.lineTo(6, 6);
                                ctx.lineTo(2, 10);
                                ctx.stroke();
                            }
                        }
                    }
                    onClicked: popup.moveMonth(1)
                }
            }
            Grid {
                columns: 7
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        required property string modelData
                        width: 32; height: 20
                        text: modelData
                        color: "#a6adc8"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font { family: "sans-serif"; pixelSize: 11 }
                        renderType: Text.NativeRendering
                    }
                }
                Repeater {
                    model: popup.weekRows * 7
                    Rectangle {
                        id: day
                        required property int index
                        readonly property int number: index - popup.firstWeekday + 1
                        readonly property bool valid: number > 0 && number <= popup.daysInMonth
                        readonly property bool isToday: valid && number === popup.today.getDate()
                            && popup.month.getMonth() === popup.today.getMonth()
                            && popup.month.getFullYear() === popup.today.getFullYear()
                        readonly property bool selected: valid && number === popup.selectedDate.getDate()
                            && popup.month.getMonth() === popup.selectedDate.getMonth()
                            && popup.month.getFullYear() === popup.selectedDate.getFullYear()
                        width: 32; height: 26
                        radius: 3
                        color: selected ? "#b4befe" : (dayMouse.containsMouse && valid ? "#313244" : "transparent")
                        border.width: isToday && !selected ? 1 : 0
                        border.color: "#b4befe"
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: day.valid ? day.number : ""
                            color: day.selected ? "#1e1e2e" : "#cdd6f4"
                            font { family: "sans-serif"; pixelSize: 12; bold: day.isToday }
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            enabled: day.valid
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.selectedDate = new Date(popup.month.getFullYear(), popup.month.getMonth(), day.number)
                        }
                    }
                }
            }
            Text {
                width: 224; height: 20
                text: "Today · " + Qt.formatDateTime(popup.today, "d MMMM")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: "#b4befe"
                font { family: "sans-serif"; pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.reset()
                }
            }
        }
    }
}
