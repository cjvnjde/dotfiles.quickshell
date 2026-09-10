// Bluetooth panel layout and primitive device rows adapted from Omarchy.
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
import Quickshell.Io
import ".."

Rectangle {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool radioEnabled: !!adapter && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    // Delegates never retain a BlueZ QObject: discovery/forget can destroy it.
    readonly property var deviceRows: devices.map(device => ({
        address: device.address,
        name: device.name || device.deviceName || device.address || "Unknown device",
        icon: device.icon || "bluetooth-active-symbolic",
        connected: device.connected,
        paired: device.paired,
        bonded: device.bonded,
        trusted: device.trusted,
        blocked: device.blocked,
        pairing: device.pairing,
        state: device.state,
        batteryAvailable: device.batteryAvailable,
        battery: device.battery,
        group: device.connected ? "CONNECTED"
            : device.paired || device.bonded || device.trusted ? "PAIRED" : "AVAILABLE"
    })).sort((left, right) => {
        const leftRank = left.connected ? 0 : left.group === "PAIRED" ? 1 : 2;
        const rightRank = right.connected ? 0 : right.group === "PAIRED" ? 1 : 2;
        return leftRank - rightRank || left.name.localeCompare(right.name);
    })
    readonly property var connectedDevices: deviceRows.filter(device => device.connected)
    readonly property var visibleRows: radioEnabled ? deviceRows.filter(device =>
        device.group !== "AVAILABLE" || adapter.discovering || device.pairing
            || device.address === pairingAddress || device.address === pendingAddress) : []
    property string selectedAddress: ""
    property string pairingAddress: ""
    readonly property BluetoothDevice pairingDevice: deviceFor(pairingAddress)
    property string forgetCandidate: ""
    property string pendingAddress: ""
    property string pendingAction: ""
    property string actionErrorAddress: ""
    property string actionError: ""
    property bool scanRequested: false
    // Only a scan started here may be stopped here. Keep the adapter while a
    // StartDiscovery reply is pending, including after the popup has closed.
    property BluetoothAdapter discoveryAdapter: null

    function deviceFor(address) {
        if (!address) return null;
        for (const device of devices) {
            if (device.address === address) return device;
        }
        return null;
    }

    function selectDevice(address) {
        if (selectedAddress !== address) forgetCandidate = "";
        selectedAddress = address;
    }

    function startDeviceAction(device, action) {
        if (!device || !radioEnabled || bluetoothAction.running || pendingAction) return;
        forgetCandidate = "";
        actionErrorAddress = "";
        actionError = "";
        pendingAddress = device.address;
        pendingAction = action;
        bluetoothAction.command = ["bash", Quickshell.shellPath("topbar/BluetoothDevice.sh"), action, device.address];
        bluetoothAction.running = true;
    }

    function finishDeviceAction(exitCode) {
        const address = pendingAddress;
        const action = pendingAction;
        const output = (bluetoothActionError.text || bluetoothActionOutput.text).trim();
        pendingAddress = "";
        pendingAction = "";
        if (exitCode === 0) return;
        const label = action === "connect" ? "Connection" : "Disconnect";
        actionErrorAddress = address;
        actionError = exitCode === 124 || exitCode === 137
            ? label + " timed out" : label + " failed";
        console.warn("Bluetooth " + action + " failed for " + address + ":",
            output || "helper exited with status " + exitCode);
    }

    function deviceStatus(device) {
        if (device.pairing || device.address === pairingAddress) return "Pairing…";
        if (pendingAction && pendingAddress === device.address)
            return pendingAction === "connect" ? "Connecting…" : "Disconnecting…";
        if (actionErrorAddress === device.address && actionError) return actionError;
        if (device.blocked) return "Blocked";
        if (device.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (device.connected) return "Connected" + (device.trusted ? " · Trusted" : "");
        if (device.paired || device.bonded) return device.trusted ? "Paired · Trusted" : "Paired";
        return device.trusted ? "Trusted" : device.address;
    }

    function actionLabel(device) {
        if (device.pairing) return "Cancel pairing";
        if (pendingAction && pendingAddress === device.address)
            return pendingAction === "connect" ? "Connecting…" : "Disconnecting…";
        if (device.blocked) return "Unblock";
        return device.connected ? "Disconnect"
            : device.paired || device.bonded || device.trusted ? "Connect" : "Pair";
    }

    function canActivate(device) {
        if (!device || !radioEnabled || pendingAction || (pairingAddress && pairingAddress !== device.address)) return false;
        return device.pairing || (!pairingAddress
            && device.state !== BluetoothDeviceState.Connecting
            && device.state !== BluetoothDeviceState.Disconnecting);
    }

    function canManage(device) {
        return canActivate(device) && !device.pairing && !pairingAddress;
    }

    function activateDevice(address) {
        const device = deviceFor(address);
        if (!canActivate(device)) return;
        forgetCandidate = "";
        actionErrorAddress = "";
        actionError = "";
        if (device.pairing) {
            pairingAddress = "";
            pairingSettleTimer.stop();
            device.cancelPair();
        } else if (device.blocked) {
            device.blocked = false;
        } else if (device.connected) {
            startDeviceAction(device, "disconnect");
        } else if (device.paired || device.bonded || device.trusted) {
            startDeviceAction(device, "connect");
        } else {
            pairingAddress = address;
            // Native BlueZ pairing preserves the desktop agent's PIN/passkey
            // and authorization prompts; do not replace it with bluetoothctl.
            device.pair();
        }
    }

    function toggleTrust(address) {
        const device = deviceFor(address);
        if (!canManage(device)) return;
        forgetCandidate = "";
        actionErrorAddress = "";
        actionError = "";
        device.trusted = !device.trusted;
    }

    function requestForget(address) {
        const device = deviceFor(address);
        if (!canManage(device) || !(device.paired || device.bonded || device.trusted)) return;
        selectDevice(address);
        if (forgetCandidate !== address) {
            forgetCandidate = address;
            return;
        }
        forgetCandidate = "";
        actionErrorAddress = "";
        actionError = "";
        device.forget();
    }

    function finishPairing() {
        const address = pairingAddress;
        const device = deviceFor(address);
        if (device && device.pairing) return;
        pairingAddress = "";
        if (!device) return;
        if (device.paired || device.bonded) {
            startDeviceAction(device, "connect");
        } else {
            actionErrorAddress = address;
            actionError = "Pairing failed";
        }
    }

    function syncDiscovery() {
        const wanted = scanRequested && bluetoothPopup.visible && radioEnabled;
        if (discoveryAdapter && !discoveryAdapter.enabled) discoveryAdapter = null;
        if (discoveryAdapter && (!wanted || discoveryAdapter !== adapter)) {
            // The native setter ignores StopDiscovery before Discovering is
            // true. Wait for that signal rather than leaking an in-flight scan.
            if (discoveryAdapter.discovering) {
                const owner = discoveryAdapter;
                discoveryAdapter = null;
                owner.discovering = false;
            }
            return;
        }
        if (!wanted || adapter.discovering) return;
        discoveryAdapter = adapter;
        adapter.discovering = true;
    }

    function toggleDiscovery() {
        if (!radioEnabled || !bluetoothPopup.visible) return;
        if (adapter.discovering && !discoveryAdapter) return;
        scanRequested = !scanRequested;
    }

    function togglePower() {
        if (!adapter || adapter.state === BluetoothAdapterState.Blocked
                || adapter.state === BluetoothAdapterState.Enabling
                || adapter.state === BluetoothAdapterState.Disabling) return;
        if (radioEnabled) {
            scanRequested = false;
            if (pairingDevice && pairingDevice.pairing) pairingDevice.cancelPair();
            pairingAddress = "";
        }
        adapter.enabled = !radioEnabled;
    }

    function moveSelection(delta) {
        if (!visibleRows.length) return;
        const index = visibleRows.findIndex(device => device.address === selectedAddress);
        const next = index < 0 ? (delta > 0 ? 0 : visibleRows.length - 1)
            : Math.max(0, Math.min(visibleRows.length - 1, index + delta));
        selectDevice(visibleRows[next].address);
        const item = deviceRepeater.itemAt(next);
        if (item) {
            const top = item.mapToItem(details, 0, 0).y;
            if (top < content.contentY) content.contentY = top;
            else if (top + item.height > content.contentY + content.height)
                content.contentY = top + item.height - content.height;
        }
    }

    onScanRequestedChanged: syncDiscovery()
    onAdapterChanged: {
        pairingAddress = "";
        selectedAddress = "";
        forgetCandidate = "";
        syncDiscovery();
    }
    onRadioEnabledChanged: {
        if (!radioEnabled) {
            pairingAddress = "";
            forgetCandidate = "";
        }
        scanRequested = radioEnabled && bluetoothPopup.visible;
        syncDiscovery();
    }
    onVisibleRowsChanged: {
        if (selectedAddress && !visibleRows.some(device => device.address === selectedAddress)) {
            selectedAddress = "";
            forgetCandidate = "";
        }
        if (pairingAddress && !deviceFor(pairingAddress)) {
            pairingAddress = "";
            pairingSettleTimer.stop();
        }
    }
    Component.onDestruction: {
        if (discoveryAdapter && discoveryAdapter.discovering) discoveryAdapter.discovering = false;
    }

    width: bluetoothRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: bluetoothMouse.containsMouse || bluetoothPopup.visible ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: "Bluetooth"

    Process {
        id: bluetoothAction
        stdout: StdioCollector { id: bluetoothActionOutput }
        stderr: StdioCollector { id: bluetoothActionError }
        onExited: function(exitCode) { root.finishDeviceAction(exitCode); }
    }
    Timer {
        id: pairingSettleTimer
        interval: 250
        onTriggered: root.finishPairing()
    }
    Timer {
        interval: 1000
        repeat: true
        running: bluetoothPopup.visible && root.scanRequested && root.radioEnabled
            && !root.adapter.discovering
        onTriggered: root.syncDiscovery()
    }
    Connections {
        target: root.pairingDevice
        function onPairedChanged() {
            if (root.pairingDevice && root.pairingDevice.paired && !root.pairingDevice.pairing)
                pairingSettleTimer.restart();
        }
        function onPairingChanged() {
            if (root.pairingDevice && !root.pairingDevice.pairing) pairingSettleTimer.restart();
        }
    }
    Connections {
        target: root.discoveryAdapter
        function onDiscoveringChanged() { root.syncDiscovery(); }
        function onEnabledChanged() { root.syncDiscovery(); }
    }

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
        property bool destructive: false
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
            color: button.destructive ? Theme.red : button.highlighted ? Theme.blue : Theme.subtext0
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
            visible: buttonMouse.containsMouse && !!text && bluetoothPopup.visible
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
        implicitWidth: Math.min(380, screen ? screen.width - 16 : 380)
        implicitHeight: Math.min(details.implicitHeight + 28,
            screen ? screen.height - Theme.barHeight - 24 : 660)
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            root.forgetCandidate = "";
            root.selectedAddress = "";
            root.scanRequested = visible && root.radioEnabled;
            root.syncDiscovery();
            if (visible) Qt.callLater(() => panel.forceActiveFocus());
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    bluetoothPopup.visible = false;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) root.moveSelection(1);
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) root.moveSelection(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.forgetCandidate) root.requestForget(root.forgetCandidate);
                    else root.activateDevice(root.selectedAddress);
                } else if (event.key === Qt.Key_Delete) root.requestForget(root.selectedAddress);
                else if (event.key === Qt.Key_T) root.toggleTrust(root.selectedAddress);
                else if (event.key === Qt.Key_B) root.togglePower();
                else if (event.key === Qt.Key_S) root.toggleDiscovery();
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
                        visible: !root.adapter || !root.radioEnabled || root.visibleRows.length === 0
                        text: !root.adapter ? "No Bluetooth adapter"
                            : root.adapter.state === BluetoothAdapterState.Blocked ? "Unblock the Bluetooth radio to continue"
                            : !root.radioEnabled ? "Turn Bluetooth on to scan"
                            : root.adapter.discovering ? "Scanning for nearby devices…" : "No devices found"
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        id: deviceRepeater
                        model: root.visibleRows
                        delegate: Column {
                            id: deviceEntry
                            required property var modelData
                            required property int index
                            readonly property bool firstInGroup: index === 0
                                || !root.visibleRows[index - 1]
                                || modelData.group !== root.visibleRows[index - 1].group
                            width: details.width
                            spacing: 6
                            Rectangle {
                                visible: deviceEntry.firstInGroup && deviceEntry.index > 0
                                width: parent.width
                                height: 1
                                color: Theme.surface0
                            }
                            SectionLabel {
                                visible: deviceEntry.firstInGroup
                                text: deviceEntry.modelData.group
                            }
                            Rectangle {
                                id: deviceCard
                                readonly property bool selected: root.selectedAddress === deviceEntry.modelData.address
                                readonly property bool remembered: deviceEntry.modelData.paired
                                    || deviceEntry.modelData.bonded || deviceEntry.modelData.trusted
                                width: parent.width
                                height: 50
                                radius: Theme.radius
                                color: selected || rowHover.hovered ? Theme.surface0 : "transparent"
                                HoverHandler { id: rowHover }
                                MouseArea {
                                    id: deviceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.canActivate(deviceEntry.modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onEntered: root.selectDevice(deviceEntry.modelData.address)
                                    onClicked: {
                                        root.selectDevice(deviceEntry.modelData.address);
                                        root.activateDevice(deviceEntry.modelData.address);
                                    }
                                }
                                Image {
                                    id: deviceIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24
                                    height: 24
                                    source: Quickshell.iconPath(deviceEntry.modelData.icon)
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                }
                                Column {
                                    anchors.left: deviceIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: secondaryActions.visible ? secondaryActions.left : batteryLabel.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    BluetoothText {
                                        width: parent.width
                                        text: deviceEntry.modelData.name
                                        color: deviceEntry.modelData.connected ? Theme.blue : Theme.text
                                        elide: Text.ElideRight
                                    }
                                    BluetoothText {
                                        width: parent.width
                                        text: root.deviceStatus(deviceEntry.modelData)
                                        color: root.actionErrorAddress === deviceEntry.modelData.address
                                            && root.actionError || deviceEntry.modelData.blocked ? Theme.red : Theme.overlay0
                                        font.pixelSize: Theme.fontSize - 2
                                        elide: Text.ElideRight
                                    }
                                }
                                BluetoothText {
                                    id: batteryLabel
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !secondaryActions.visible && deviceEntry.modelData.connected
                                        && deviceEntry.modelData.batteryAvailable
                                    width: visible ? implicitWidth : 0
                                    text: Math.round(deviceEntry.modelData.battery * 100) + "%"
                                    color: Theme.subtext0
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                Row {
                                    id: secondaryActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: deviceCard.remembered && (deviceCard.selected || rowHover.hovered)
                                    spacing: 2
                                    ActionButton {
                                        text: "󰒃"
                                        highlighted: deviceEntry.modelData.trusted
                                        hint: deviceEntry.modelData.trusted ? "Untrust" : "Trust"
                                        enabled: root.canManage(deviceEntry.modelData)
                                        onClicked: root.toggleTrust(deviceEntry.modelData.address)
                                    }
                                    ActionButton {
                                        text: "󰅙"
                                        hint: "Forget device"
                                        destructive: root.forgetCandidate === deviceEntry.modelData.address
                                        enabled: root.canManage(deviceEntry.modelData)
                                        onClicked: root.requestForget(deviceEntry.modelData.address)
                                    }
                                }
                                BluetoothTooltip {
                                    anchor.item: deviceCard
                                    visible: deviceMouse.containsMouse && bluetoothPopup.visible
                                    text: root.actionLabel(deviceEntry.modelData)
                                        + (deviceEntry.modelData.batteryAvailable
                                            ? " · Battery " + Math.round(deviceEntry.modelData.battery * 100) + "%" : "")
                                }
                            }
                            Row {
                                visible: root.forgetCandidate === deviceEntry.modelData.address
                                anchors.right: parent.right
                                spacing: 6
                                ActionButton {
                                    text: "Cancel"
                                    onClicked: root.forgetCandidate = ""
                                }
                                ActionButton {
                                    text: "Forget device?"
                                    destructive: true
                                    enabled: root.canManage(deviceEntry.modelData)
                                    onClicked: root.requestForget(deviceEntry.modelData.address)
                                }
                            }
                        }
                    }
                    BluetoothText {
                        width: parent.width
                        visible: root.radioEnabled && !!root.actionError
                            && !root.visibleRows.some(device => device.address === root.actionErrorAddress)
                        text: root.actionError
                        color: Theme.red
                        font.pixelSize: Theme.fontSize - 2
                        wrapMode: Text.Wrap
                    }
                    Item {
                        width: parent.width
                        height: 26
                        visible: !!root.adapter && root.radioEnabled
                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.adapter && root.adapter.discovering ? "Scanning"
                                : root.scanRequested ? "Starting scan…" : "Discovery paused"
                        }
                        ActionButton {
                            anchors.right: parent.right
                            text: root.adapter && root.adapter.discovering && !root.discoveryAdapter ? "In use"
                                : root.scanRequested ? "Stop scan" : "Scan"
                            hint: root.adapter && root.adapter.discovering && !root.discoveryAdapter
                                ? "Another client is scanning" : "Scan for nearby devices"
                            enabled: root.radioEnabled && (!root.adapter.discovering || !!root.discoveryAdapter)
                            onClicked: root.toggleDiscovery()
                        }
                    }
                }
            }
        }
    }
}
