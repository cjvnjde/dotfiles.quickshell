import QtQuick
import Quickshell
import Quickshell.Networking

Rectangle {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: Networking.devices.values.find(device => device.type === DeviceType.Wired) || null
    readonly property var activeWifi: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected) || null
        : null
    readonly property bool wiredConnected: wiredDevice !== null && wiredDevice.connected
    property var passwordNetwork: null

    function signalIcon(strength) {
        if (strength >= 0.75) {
            return "󰤨";
        }
        if (strength >= 0.5) {
            return "󰤥";
        }
        if (strength >= 0.25) {
            return "󰤢";
        }

        return "󰤟";
    }

    function selectNetwork(network) {
        if (network.stateChanging) {
            return;
        }
        if (network.connected) {
            network.disconnect();
            return;
        }
        const usesPsk = network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
        if (network.known || !usesPsk) {
            network.connect();
            return;
        }

        passwordNetwork = network;
        passwordInput.text = "";
        passwordInput.forceActiveFocus();
    }

    width: networkRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: networkMouse.containsMouse ? Theme.surface1 : Theme.surface0

    Row {
        id: networkRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.wiredConnected
                ? "󰈀"
                : root.activeWifi ? root.signalIcon(root.activeWifi.signalStrength) : "󰤭"
            color: root.wiredConnected || root.activeWifi ? Theme.green : Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activeWifi !== null
            width: Math.min(implicitWidth, 110)
            text: root.activeWifi ? root.activeWifi.name : ""
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: networkMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && Networking.wifiHardwareEnabled) {
                Networking.wifiEnabled = !Networking.wifiEnabled;
                return;
            }

            networkPopup.visible = !networkPopup.visible;
            if (networkPopup.visible && root.wifiDevice && Networking.wifiEnabled) {
                root.wifiDevice.scannerEnabled = true;
            }
        }
    }

    PopupWindow {
        id: networkPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        width: 340
        height: 390
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            if (!visible) {
                root.passwordNetwork = null;
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
                text: root.wiredConnected ? "Network · Ethernet" : "Wi-Fi networks"
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
                color: Networking.wifiEnabled ? Theme.blue : Theme.surface1
                opacity: Networking.wifiHardwareEnabled ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: Networking.wifiEnabled ? "On" : "Off"
                    color: Networking.wifiEnabled ? Theme.base : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Networking.wifiHardwareEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
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
                color: root.wifiDevice && root.wifiDevice.scannerEnabled ? Theme.green : Theme.surface1
                opacity: root.wifiDevice && Networking.wifiEnabled ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.wifiDevice && root.wifiDevice.scannerEnabled ? "Scanning" : "Scan"
                    color: root.wifiDevice && root.wifiDevice.scannerEnabled ? Theme.base : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.wifiDevice !== null && Networking.wifiEnabled
                    onClicked: root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled
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
                visible: !root.wifiDevice || !Networking.wifiEnabled
                text: !root.wifiDevice ? "No Wi-Fi adapter" : "Wi-Fi is off"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                id: networkList
                anchors {
                    top: parent.top
                    bottom: passwordPanel.visible ? passwordPanel.top : parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 52
                    bottomMargin: 8
                    leftMargin: 8
                    rightMargin: 8
                }
                visible: root.wifiDevice !== null && Networking.wifiEnabled
                clip: true
                spacing: 4
                model: ScriptModel {
                    values: root.wifiDevice
                        ? root.wifiDevice.networks.values.slice().sort((left, right) => right.signalStrength - left.signalStrength)
                        : []
                    objectProp: "name"
                }

                delegate: Rectangle {
                    required property var modelData

                    width: ListView.view.width
                    height: 48
                    radius: Theme.radius
                    color: networkItemMouse.containsMouse ? Theme.surface1 : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 8
                        }
                        text: root.signalIcon(modelData.signalStrength)
                        color: modelData.connected ? Theme.green : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: networkStatus.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 34
                            rightMargin: 8
                        }
                        text: modelData.name
                        color: modelData.connected ? Theme.blue : Theme.text
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        id: networkStatus
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8
                        }
                        text: modelData.stateChanging
                            ? "Working…"
                            : modelData.connected ? "Disconnect" : modelData.known ? "Connect" : "Join"
                        color: modelData.connected ? Theme.green : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }

                    MouseArea {
                        id: networkItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.selectNetwork(modelData)
                    }
                }
            }

            Rectangle {
                id: passwordPanel
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    margins: 8
                }
                visible: root.passwordNetwork !== null
                height: visible ? 82 : 0
                radius: Theme.radius
                color: Theme.mantle
                border.color: Theme.surface1

                Text {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 8
                        leftMargin: 10
                        rightMargin: 10
                    }
                    text: root.passwordNetwork ? "Password for " + root.passwordNetwork.name : ""
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: connectButton.left
                        bottomMargin: 8
                        leftMargin: 8
                        rightMargin: 8
                    }
                    height: 30
                    radius: Theme.radius
                    color: Theme.surface0

                    TextInput {
                        id: passwordInput
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: Theme.blue
                        echoMode: TextInput.Password
                        clip: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        onAccepted: connectButton.connectNetwork()
                    }
                }

                Rectangle {
                    id: connectButton

                    function connectNetwork() {
                        if (!root.passwordNetwork || passwordInput.text.length === 0) {
                            return;
                        }

                        root.passwordNetwork.connectWithPsk(passwordInput.text);
                        root.passwordNetwork = null;
                    }

                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        margins: 8
                    }
                    width: 68
                    height: 30
                    radius: Theme.radius
                    color: passwordInput.text.length > 0 ? Theme.blue : Theme.surface1

                    Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: passwordInput.text.length > 0 ? Theme.base : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: passwordInput.text.length > 0
                        onClicked: connectButton.connectNetwork()
                    }
                }
            }
        }
    }
}
