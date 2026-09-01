import QtQuick
import Quickshell
import Quickshell.Bluetooth
import ".."

Rectangle {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property var connectedDevices: Bluetooth.devices.values.filter(device => device.connected)
    readonly property var sortedDevices: adapter
        ? adapter.devices.values.slice().sort((left, right) => {
            const rankDifference = root.deviceRank(left) - root.deviceRank(right);
            if (rankDifference !== 0) {
                return rankDifference;
            }

            return root.deviceName(left).localeCompare(root.deviceName(right));
        })
        : []
    property bool managesDiscovery: false
    property var pairingDevice: null
    property string forgetCandidate: ""

    function deviceName(device) {
        return device.name || device.deviceName || device.address || "Unknown device";
    }

    function deviceRank(device) {
        if (device.connected) {
            return 0;
        }
        if (device.paired || device.bonded) {
            return 1;
        }

        return 2;
    }

    function deviceGroup(device) {
        const rank = deviceRank(device);
        if (rank === 0) {
            return "Connected";
        }
        if (rank === 1) {
            return "Paired";
        }

        return "Available";
    }

    function stateChanging(device) {
        return device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting;
    }

    function deviceStatus(device) {
        if (device.blocked) {
            return "Blocked";
        }
        if (device.pairing) {
            return "Pairing…";
        }
        if (device.state === BluetoothDeviceState.Connecting) {
            return "Connecting…";
        }
        if (device.state === BluetoothDeviceState.Disconnecting) {
            return "Disconnecting…";
        }
        if (device.connected) {
            const battery = device.batteryAvailable ? " · " + Math.round(device.battery * 100) + "%" : "";
            const trust = device.trusted ? " · Trusted" : "";
            return "Connected" + battery + trust;
        }
        if (device.paired || device.bonded) {
            return device.trusted ? "Paired · Trusted" : "Paired · Not trusted";
        }

        return device.address || "Ready to pair";
    }

    function actionLabel(device) {
        if (pairingDevice && pairingDevice !== device) {
            return "Wait…";
        }
        if (device.blocked) {
            return "Unblock";
        }
        if (device.pairing) {
            return "Cancel";
        }
        if (device.state === BluetoothDeviceState.Connecting) {
            return "Connecting";
        }
        if (device.state === BluetoothDeviceState.Disconnecting) {
            return "Stopping";
        }
        if (device.connected) {
            return "Disconnect";
        }
        if (device.paired || device.bonded) {
            return "Connect";
        }

        return "Pair";
    }

    function canActivate(device) {
        return (!pairingDevice || pairingDevice === device)
            && device.state !== BluetoothDeviceState.Connecting
            && device.state !== BluetoothDeviceState.Disconnecting;
    }

    function activateDevice(device) {
        forgetCandidate = "";
        if (!canActivate(device)) {
            return;
        }
        if (device.blocked) {
            device.blocked = false;
            return;
        }
        if (device.pairing) {
            device.cancelPair();
            if (pairingDevice === device) {
                pairingDevice = null;
            }
            return;
        }
        if (device.connected) {
            device.disconnect();
            return;
        }
        if (device.paired || device.bonded) {
            device.connect();
            return;
        }

        pairingDevice = device;
        device.pair();
    }

    function requestForget(device) {
        if (forgetCandidate !== device.address) {
            forgetCandidate = device.address;
            return;
        }

        if (pairingDevice === device) {
            pairingDevice = null;
        }
        forgetCandidate = "";
        device.forget();
    }

    function finishPairing() {
        const device = pairingDevice;
        if (device && device.paired) {
            device.trusted = true;
            device.connect();
        }
        pairingDevice = null;
    }

    function startDiscovery() {
        if (!adapter || !enabled || adapter.discovering) {
            return;
        }

        adapter.discovering = true;
        managesDiscovery = true;
    }

    function stopManagedDiscovery() {
        if (adapter && managesDiscovery && adapter.discovering) {
            adapter.discovering = false;
        }
        managesDiscovery = false;
    }

    function toggleDiscovery() {
        if (!adapter || !enabled) {
            return;
        }
        if (adapter.discovering) {
            adapter.discovering = false;
            managesDiscovery = false;
        } else {
            adapter.discovering = true;
            managesDiscovery = true;
        }
    }

    width: bluetoothRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: bluetoothMouse.containsMouse ? Theme.surface1 : Theme.surface0

    Timer {
        id: pairingSettleTimer
        interval: 250
        onTriggered: root.finishPairing()
    }

    Connections {
        target: root.pairingDevice

        function onPairedChanged() {
            if (root.pairingDevice && root.pairingDevice.paired) {
                pairingSettleTimer.stop();
                root.finishPairing();
            }
        }

        function onPairingChanged() {
            if (root.pairingDevice && !root.pairingDevice.pairing) {
                pairingSettleTimer.restart();
            }
        }
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() {
            if (!root.enabled) {
                root.managesDiscovery = false;
                root.pairingDevice = null;
            } else if (bluetoothPopup.visible) {
                root.startDiscovery();
            }
        }
    }

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
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connectedDevices.length > 0
            width: Math.min(implicitWidth, 110)
            text: root.connectedDevices.length === 1
                ? root.deviceName(root.connectedDevices[0])
                : root.connectedDevices.length + " connected"
            color: Theme.text
            elide: Text.ElideRight
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
        width: 410
        height: 430
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            root.forgetCandidate = "";
            if (visible) {
                root.startDiscovery();
            } else {
                root.stopManagedDiscovery();
            }
        }

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
                text: "Bluetooth devices"
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
                height: 28
                radius: height / 2
                color: root.enabled ? Theme.blue : Theme.surface1
                opacity: root.adapter ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.enabled ? "On" : "Off"
                    color: root.enabled ? Theme.base : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.adapter !== null
                    onClicked: root.adapter.enabled = !root.adapter.enabled
                }
            }

            Rectangle {
                id: scanButton
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 9
                    rightMargin: 9
                }
                width: 86
                height: 28
                radius: height / 2
                color: root.adapter && root.adapter.discovering ? Theme.green : Theme.surface1
                opacity: root.enabled ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.adapter && root.adapter.discovering ? "Scanning…" : "Scan"
                    color: root.adapter && root.adapter.discovering ? Theme.base : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    onClicked: root.toggleDiscovery()
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 47
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 1
                color: Theme.surface1
            }

            Text {
                anchors.centerIn: parent
                visible: !root.adapter || !root.enabled || root.sortedDevices.length === 0
                text: !root.adapter
                    ? "No Bluetooth adapter"
                    : !root.enabled ? "Bluetooth is off" : "Scanning for nearby devices…"
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
                    topMargin: 54
                    bottomMargin: 8
                    leftMargin: 8
                    rightMargin: 8
                }
                visible: root.adapter !== null && root.enabled && root.sortedDevices.length > 0
                clip: true
                spacing: 4
                model: ScriptModel {
                    values: root.sortedDevices
                    objectProp: "address"
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool firstInGroup: index === 0
                        || root.deviceGroup(modelData) !== root.deviceGroup(root.sortedDevices[index - 1])

                    width: ListView.view.width
                    height: firstInGroup ? 84 : 60

                    Text {
                        visible: parent.firstInGroup
                        anchors {
                            top: parent.top
                            left: parent.left
                            leftMargin: 8
                        }
                        height: 22
                        text: root.deviceGroup(parent.modelData)
                        color: Theme.subtext0
                        font.bold: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }

                    Rectangle {
                        id: deviceCard
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 58
                        radius: Theme.radius
                        color: deviceMouse.containsMouse || mainMouse.containsMouse
                            || trustMouse.containsMouse || forgetMouse.containsMouse
                            ? Theme.surface0 : "transparent"

                        Image {
                            id: deviceIcon
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            width: 26
                            height: 26
                            source: Quickshell.iconPath(modelData.icon || "bluetooth-active-symbolic")
                            sourceSize.width: 26
                            sourceSize.height: 26
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors {
                                left: deviceIcon.right
                                right: trustButton.left
                                top: parent.top
                                leftMargin: 9
                                rightMargin: 8
                                topMargin: 10
                            }
                            text: root.deviceName(modelData)
                            color: modelData.connected ? Theme.blue : Theme.text
                            elide: Text.ElideRight
                            font.bold: modelData.connected
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors {
                                left: deviceIcon.right
                                right: trustButton.left
                                bottom: parent.bottom
                                leftMargin: 9
                                rightMargin: 8
                                bottomMargin: 9
                            }
                            text: root.deviceStatus(modelData)
                            color: modelData.blocked ? Theme.red
                                : modelData.connected ? Theme.green : Theme.subtext0
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }

                        MouseArea {
                            id: deviceMouse
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                left: parent.left
                                right: trustButton.left
                            }
                            hoverEnabled: true
                            enabled: root.canActivate(modelData)
                            onClicked: root.activateDevice(modelData)
                        }

                        Rectangle {
                            id: trustButton
                            anchors {
                                right: forgetButton.left
                                verticalCenter: parent.verticalCenter
                                rightMargin: 5
                            }
                            visible: modelData.paired || modelData.bonded
                            width: visible ? 56 : 0
                            height: 28
                            radius: height / 2
                            color: modelData.trusted ? Theme.green
                                : trustMouse.containsMouse ? Theme.surface2 : Theme.surface1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.trusted ? "Trusted" : "Trust"
                                color: modelData.trusted ? Theme.base : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }

                            MouseArea {
                                id: trustMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.forgetCandidate = "";
                                    modelData.trusted = !modelData.trusted;
                                }
                            }
                        }

                        Rectangle {
                            id: forgetButton
                            anchors {
                                right: mainButton.left
                                verticalCenter: parent.verticalCenter
                                rightMargin: 5
                            }
                            visible: modelData.paired || modelData.bonded
                            width: visible ? 58 : 0
                            height: 28
                            radius: height / 2
                            color: root.forgetCandidate === modelData.address
                                ? Theme.red : forgetMouse.containsMouse ? Theme.surface2 : Theme.surface1

                            Text {
                                anchors.centerIn: parent
                                text: root.forgetCandidate === modelData.address ? "Confirm" : "Forget"
                                color: root.forgetCandidate === modelData.address ? Theme.base : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.requestForget(modelData)
                            }
                        }

                        Rectangle {
                            id: mainButton
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 8
                            }
                            width: 78
                            height: 30
                            radius: height / 2
                            color: !root.canActivate(modelData) ? Theme.surface0
                                : modelData.connected ? Theme.red
                                : mainMouse.containsMouse ? Theme.lavender : Theme.blue
                            opacity: root.canActivate(modelData) ? 1 : 0.65

                            Text {
                                anchors.centerIn: parent
                                text: root.actionLabel(modelData)
                                color: root.canActivate(modelData) ? Theme.base : Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }

                            MouseArea {
                                id: mainMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.canActivate(modelData)
                                onClicked: root.activateDevice(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
