// Bluetooth panel layout adapted from Omarchy.
// Source: https://github.com/basecamp/omarchy
// SPDX-License-Identifier: MIT
// Copyright (c) David Heinemeier Hansson
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import ".."

Rectangle {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool radioEnabled: !!adapter && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var pairedRows: devices.map(device => ({
        address: device.address,
        name: device.name || device.deviceName || device.address || "Unknown device",
        icon: device.icon || "bluetooth-active-symbolic",
        connected: device.connected,
        paired: device.paired,
        bonded: device.bonded,
        trusted: device.trusted,
        blocked: device.blocked,
        state: device.state,
        batteryAvailable: device.batteryAvailable,
        battery: device.battery
    })).filter(device => device.connected || device.paired || device.bonded || device.trusted)
        .sort((left, right) => {
            if (left.connected !== right.connected) return left.connected ? -1 : 1;
            return left.name.localeCompare(right.name);
        })
    readonly property var connectedDevices: pairedRows.filter(device => device.connected)

    function deviceStatus(device) {
        if (device.blocked) return "Blocked";
        if (device.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (device.connected) return "Connected" + (device.trusted ? " · Trusted" : "");
        if (device.paired || device.bonded) return device.trusted ? "Paired · Trusted" : "Paired";
        return device.trusted ? "Trusted" : device.address;
    }

    function togglePower() {
        if (!adapter || adapter.state === BluetoothAdapterState.Blocked
                || adapter.state === BluetoothAdapterState.Enabling
                || adapter.state === BluetoothAdapterState.Disabling) return;
        adapter.enabled = !radioEnabled;
    }

    width: bluetoothRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: bluetoothMouse.containsMouse || bluetoothPopup.visible ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: "Bluetooth"

    component BluetoothText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        textFormat: Text.PlainText
    }

    component SectionLabel: BluetoothText {
        color: Theme.overlay0
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
    }

    component BluetoothTooltip: PopupWindow {
        id: tooltipWindow
        property string text: ""
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: tooltip.implicitWidth + 20
        implicitHeight: tooltip.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            BluetoothText {
                id: tooltip
                anchors.centerIn: parent
                text: tooltipWindow.text
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }

    component ActionButton: Rectangle {
        id: button
        property string text: ""
        property string hint: ""
        property bool highlighted: false
        signal clicked()

        implicitWidth: Math.max(28, label.implicitWidth + 16)
        implicitHeight: 26
        radius: height / 2
        color: buttonMouse.containsMouse ? Theme.surface1 : highlighted ? Theme.surface0 : "transparent"
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        border.width: activeFocus ? 1 : 0
        border.color: Theme.overlay0
        Accessible.role: Accessible.Button
        Accessible.name: hint || text
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        BluetoothText {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.highlighted ? Theme.blue : Theme.subtext0
            font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        BluetoothTooltip {
            anchor.item: button
            visible: buttonMouse.containsMouse && !!button.hint && bluetoothPopup.visible
            text: button.hint
        }
    }

    Row {
        id: bluetoothRow
        anchors.centerIn: parent
        spacing: 5

        BluetoothText {
            text: root.connectedDevices.length ? "󰂱" : root.radioEnabled ? "󰂯" : "󰂲"
            color: root.connectedDevices.length ? Theme.blue : root.radioEnabled ? Theme.text : Theme.overlay0
            font.pixelSize: Theme.fontSize + 2
        }

        BluetoothText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connectedDevices.length > 0
            width: Math.min(implicitWidth, 110)
            text: root.connectedDevices.length === 1 ? root.connectedDevices[0].name
                : root.connectedDevices.length + " connected"
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: bluetoothMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.togglePower();
            else bluetoothPopup.visible = !bluetoothPopup.visible;
        }
    }

    PopupWindow {
        id: bluetoothPopup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: Math.min(360, screen ? screen.width - 16 : 360)
        implicitHeight: Math.min(details.implicitHeight + 28,
            screen ? screen.height - Theme.barHeight - 24 : 520)
        color: "transparent"
        grabFocus: true
        onVisibleChanged: if (visible) Qt.callLater(() => panel.forceActiveFocus())

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) bluetoothPopup.visible = false;
                else if (event.key === Qt.Key_B) root.togglePower();
                else return;
                event.accepted = true;
            }

            Flickable {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: details.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: details
                    width: content.width
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 36

                        BluetoothText {
                            id: headerIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.radioEnabled ? "󰂯" : "󰂲"
                            color: root.radioEnabled ? Theme.blue : Theme.overlay0
                            font.pixelSize: Theme.fontSize + 10
                        }

                        Column {
                            anchors.left: headerIcon.right
                            anchors.leftMargin: 12
                            anchors.right: powerButton.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            BluetoothText { text: "Bluetooth"; font.bold: true }
                            SectionLabel {
                                width: parent.width
                                visible: !!root.adapter
                                text: !root.adapter ? "" : root.adapter.state === BluetoothAdapterState.Blocked
                                    ? "Radio blocked" : root.adapter.state === BluetoothAdapterState.Enabling
                                    ? "Turning on…" : root.adapter.state === BluetoothAdapterState.Disabling
                                    ? "Turning off…" : root.radioEnabled ? root.adapter.name : "Turned off"
                                elide: Text.ElideRight
                            }
                        }

                        ActionButton {
                            id: powerButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.radioEnabled ? "On" : "Off"
                            highlighted: root.radioEnabled
                            hint: "Turn Bluetooth " + (root.radioEnabled ? "off" : "on")
                            enabled: !!root.adapter && root.adapter.state !== BluetoothAdapterState.Blocked
                                && root.adapter.state !== BluetoothAdapterState.Enabling
                                && root.adapter.state !== BluetoothAdapterState.Disabling
                            onClicked: root.togglePower()
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surface0 }

                    BluetoothText {
                        width: parent.width
                        visible: !root.adapter || !root.radioEnabled || root.pairedRows.length === 0
                        text: !root.adapter ? "No Bluetooth adapter"
                            : root.adapter.state === BluetoothAdapterState.Blocked ? "Unblock the Bluetooth radio to continue"
                            : !root.radioEnabled ? "Turn Bluetooth on to view paired devices"
                            : "No paired devices"
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.Wrap
                    }

                    SectionLabel {
                        visible: root.radioEnabled && root.pairedRows.length > 0
                        text: "Paired devices"
                    }

                    Repeater {
                        model: root.radioEnabled ? root.pairedRows : []

                        delegate: Rectangle {
                            id: deviceCard
                            required property var modelData

                            width: details.width
                            height: 50
                            radius: Theme.radius
                            color: rowHover.hovered ? Theme.surface0 : "transparent"
                            HoverHandler { id: rowHover }

                            Image {
                                id: deviceIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                source: Quickshell.iconPath(deviceCard.modelData.icon)
                                sourceSize.width: 24
                                sourceSize.height: 24
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                anchors.left: deviceIcon.right
                                anchors.leftMargin: 10
                                anchors.right: batteryLabel.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                BluetoothText {
                                    width: parent.width
                                    text: deviceCard.modelData.name
                                    color: deviceCard.modelData.connected ? Theme.blue : Theme.text
                                    elide: Text.ElideRight
                                }

                                BluetoothText {
                                    width: parent.width
                                    text: root.deviceStatus(deviceCard.modelData)
                                    color: deviceCard.modelData.blocked ? Theme.red : Theme.overlay0
                                    font.pixelSize: Theme.fontSize - 2
                                    elide: Text.ElideRight
                                }
                            }

                            BluetoothText {
                                id: batteryLabel
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: deviceCard.modelData.connected && deviceCard.modelData.batteryAvailable
                                width: visible ? implicitWidth : 0
                                text: Math.round(deviceCard.modelData.battery * 100) + "%"
                                color: Theme.subtext0
                                font.pixelSize: Theme.fontSize - 2
                            }

                            BluetoothTooltip {
                                anchor.item: deviceCard
                                visible: rowHover.hovered && bluetoothPopup.visible
                                text: root.deviceStatus(deviceCard.modelData)
                                    + (deviceCard.modelData.batteryAvailable
                                        ? " · Battery " + Math.round(deviceCard.modelData.battery * 100) + "%" : "")
                            }
                        }
                    }
                }
            }
        }
    }
}
