import QtQuick
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property var connectedDevices: Bluetooth.devices.values.filter(device => device.connected)

    width: bluetoothRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: bluetoothMouse.containsMouse ? Theme.surface1 : Theme.surface0

    Row {
        id: bluetoothRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.connectedDevices.length > 0 ? "󰂱" : root.enabled ? "󰂯" : "󰂲"
            color: root.connectedDevices.length > 0 ? Theme.blue : root.enabled ? Theme.text : Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            visible: root.connectedDevices.length > 0
            text: root.connectedDevices.length
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: bluetoothMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.adapter) {
                root.adapter.enabled = !root.adapter.enabled;
                return;
            }

            bluetoothPopup.visible = !bluetoothPopup.visible;
        }
    }

    PopupWindow {
        id: bluetoothPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        width: 320
        height: Math.min(390, 104 + deviceList.contentHeight)
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
                    margins: 14
                }
                text: "Bluetooth"
                color: Theme.text
                font.bold: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
            }

            Rectangle {
                anchors {
                    top: parent.top
                    right: scanButton.left
                    topMargin: 9
                    rightMargin: 8
                }
                width: 62
                height: 26
                radius: height / 2
                color: root.enabled ? Theme.blue : Theme.surface1

                Text {
                    anchors.centerIn: parent
                    text: root.enabled ? "On" : "Off"
                    color: root.enabled ? Theme.base : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.adapter) {
                            root.adapter.enabled = !root.adapter.enabled;
                        }
                    }
                }
            }

            Rectangle {
                id: scanButton
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 9
                }
                width: 74
                height: 26
                radius: height / 2
                color: root.adapter && root.adapter.discovering ? Theme.green : Theme.surface1
                opacity: root.enabled ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.adapter && root.adapter.discovering ? "Stop" : "Scan"
                    color: root.adapter && root.adapter.discovering ? Theme.base : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 45
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 1
                color: Theme.surface1
            }

            Text {
                anchors.centerIn: parent
                visible: !root.adapter || !root.enabled || root.adapter.devices.values.length === 0
                text: !root.adapter ? "No Bluetooth adapter" : !root.enabled ? "Bluetooth is off" : "No devices found"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                id: deviceList
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 52
                    margins: 8
                }
                clip: true
                spacing: 4
                model: root.adapter ? root.adapter.devices : null

                delegate: Rectangle {
                    required property var modelData

                    width: ListView.view.width
                    height: 50
                    radius: Theme.radius
                    color: deviceMouse.containsMouse ? Theme.surface1 : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 8
                        }
                        width: parent.width - deviceStatus.width - 32
                        text: modelData.name || modelData.deviceName || modelData.address
                        color: modelData.connected ? Theme.blue : Theme.text
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        id: deviceStatus
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8
                        }
                        text: modelData.pairing
                            ? "Pairing…"
                            : modelData.connected
                                ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  Disconnect" : "Disconnect")
                                : modelData.paired ? "Connect" : "Pair"
                        color: modelData.connected ? Theme.green : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }

                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !modelData.pairing
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect();
                            } else if (modelData.paired) {
                                modelData.connect();
                            } else {
                                modelData.pair();
                            }
                        }
                    }
                }
            }
        }
    }
}
