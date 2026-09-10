// Adapted from Omarchy's network panel.
// Source: https://github.com/basecamp/omarchy
// SPDX-License-Identifier: MIT
//
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
import Quickshell.Io
import Quickshell.Networking
import ".."

Rectangle {
    id: root

    readonly property bool managerAvailable: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(network => network.connected) || null
    readonly property bool wiredConnected: !!wiredDevice && wiredDevice.connected
    readonly property string fallbackInterface: wiredConnected ? wiredDevice.name
        : activeWifi ? wifiDevice.name : ""
    readonly property var detailDevice: devices.find(device => device.name === info.iface) || null
    readonly property var detailNetwork: !detailDevice ? null
        : detailDevice.type === DeviceType.Wired ? detailDevice.network
        : detailDevice.networks.values.find(network => network.connected) || null
    readonly property string connectionKind: detailDevice
        ? detailDevice.type === DeviceType.Wired ? "Ethernet" : "Wi-Fi"
        : info.iface ? (info.wireless ? "Wi-Fi" : "Network")
        : wiredConnected ? "Ethernet" : activeWifi ? "Wi-Fi" : "Network"
    readonly property string linkSpeed: detailDevice && detailDevice.type === DeviceType.Wired && detailDevice.linkSpeed > 0
        ? (detailDevice.linkSpeed >= 1000 ? (detailDevice.linkSpeed / 1000).toFixed(1) + " Gbit/s"
            : detailDevice.linkSpeed + " Mbit/s") : ""
    property var info: ({})
    property string detailsError: ""
    property bool sampled: false
    property real receiving: -1
    property real sending: -1
    property var internetSamples: []
    property var routerSamples: []
    readonly property int packetLoss: internetSamples.length
        ? Math.round(internetSamples.filter(value => value === null).length * 100 / internetSamples.length) : 0
    property int generation: 0
    property var scannerDevice: null
    property bool scanEnabled: true
    property var passwordNetwork: null
    property var actionNetwork: null
    property string actionKind: ""
    property string actionError: ""
    readonly property bool busy: actionKind !== ""

    function findDevice(type) {
        const matches = devices.filter(device => device.type === type);
        return matches.find(device => device.connected) || matches[0] || null;
    }

    function signalIcon(strength) {
        return strength >= 0.75 ? "󰤨" : strength >= 0.5 ? "󰤥" : strength >= 0.25 ? "󰤢" : "󰤟";
    }

    function bytes(value) {
        if (value === undefined || value === null || value < 0) return "—";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let amount = Number(value);
        let index = 0;
        while (amount >= 1024 && index < units.length - 1) { amount /= 1024; ++index; }
        return amount.toFixed(index ? 1 : 0) + " " + units[index];
    }

    function latency(samples) {
        if (!samples.length) return "—";
        const received = samples.slice(-5).filter(value => typeof value === "number");
        if (!received.length) return "Timeout";
        const average = received.reduce((sum, value) => sum + value, 0) / received.length;
        return average.toFixed(average < 10 ? 1 : 0) + " ms";
    }

    function updateDetails(next) {
        if (next.stale) { resetDetails(); return; }
        const sameLink = info.iface && info.iface === next.iface && info.gateway === next.gateway;
        const elapsed = sameLink ? next.sampleTime - info.sampleTime : 0;
        receiving = elapsed > 0 && next.rx !== null && info.rx !== null && next.rx >= info.rx
            ? (next.rx - info.rx) / elapsed : -1;
        sending = elapsed > 0 && next.tx !== null && info.tx !== null && next.tx >= info.tx
            ? (next.tx - info.tx) / elapsed : -1;
        internetSamples = next.internetPing === undefined || next.internetPing === "unavailable" ? []
            : (sameLink ? internetSamples : []).concat([next.internetPing]).slice(-24);
        routerSamples = next.routerPing === undefined || next.routerPing === "unavailable" ? []
            : (sameLink ? routerSamples : []).concat([next.routerPing]).slice(-24);
        info = next;
        sampled = true;
        detailsError = next.error || "";
    }

    function resetDetails() {
        info = {};
        receiving = -1;
        sending = -1;
        internetSamples = [];
        routerSamples = [];
        sampled = false;
        detailsError = "";
    }

    function refreshDetails() {
        if (!networkPopup.visible || sampler.running) return;
        sampler.requestGeneration = generation;
        sampler.startedSuccessfully = false;
        sampler.command = ["python3", Quickshell.shellPath("topbar/NetworkStatus.py"), fallbackInterface];
        sampler.running = true;
    }

    function syncScanner() {
        const next = networkPopup.visible && Networking.wifiEnabled && Networking.wifiHardwareEnabled
            && scanEnabled ? wifiDevice : null;
        if (scannerDevice && scannerDevice !== next) scannerDevice.scannerEnabled = false;
        scannerDevice = next;
        if (scannerDevice) scannerDevice.scannerEnabled = true;
    }

    function usesPsk(network) {
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.Sae;
    }

    function clearPassword() {
        passwordNetwork = null;
        passwordInput.text = "";
        if (networkPopup.visible) panel.forceActiveFocus();
    }

    function promptPassword(network) {
        passwordNetwork = network;
        passwordInput.text = "";
        Qt.callLater(() => {
            if (!root.passwordNetwork || !networkPopup.visible) return;
            passwordInput.forceActiveFocus();
            content.contentY = Math.max(0, details.implicitHeight - content.height);
        });
    }

    function runAction(network, kind, secret) {
        if (busy || !network || network.stateChanging || wifiNetworks.indexOf(network) < 0) return;
        actionNetwork = network;
        actionKind = kind;
        actionError = "";
        actionTimeout.restart();
        if (kind === "disconnect") network.disconnect();
        else if (kind === "forget") network.forget();
        else if (secret !== undefined) network.connectWithPsk(secret);
        else network.connect();
    }

    function selectNetwork(network) {
        if (busy || network.stateChanging) return;
        clearPassword();
        if (network.connected) { runAction(network, "disconnect"); return; }
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            runAction(network, "connect");
        } else if (usesPsk(network)) {
            actionError = "";
            promptPassword(network);
        } else {
            actionError = "Configure this network's " + WifiSecurityType.toString(network.security) + " credentials in NetworkManager first.";
        }
    }

    function submitPassword() {
        if (!passwordNetwork || !passwordInput.text.length || busy) return;
        const network = passwordNetwork;
        const secret = passwordInput.text;
        clearPassword();
        runAction(network, "connect", secret);
    }

    function clearAction() {
        actionTimeout.stop();
        actionKind = "";
        actionNetwork = null;
    }

    function checkAction() {
        if (!actionNetwork || !busy) return;
        if ((actionKind === "connect" && actionNetwork.connected)
            || (actionKind === "disconnect" && !actionNetwork.connected && !actionNetwork.stateChanging)
            || (actionKind === "forget" && !actionNetwork.known && !actionNetwork.stateChanging)) {
            clearAction();
            refreshDetails();
        }
    }

    onFallbackInterfaceChanged: {
        ++generation;
        sampler.running = false;
        resetDetails();
        refreshDetails();
    }
    onWifiDeviceChanged: syncScanner()
    onScanEnabledChanged: syncScanner()
    onWifiNetworksChanged: {
        if (passwordNetwork && wifiNetworks.indexOf(passwordNetwork) < 0) clearPassword();
        if (actionNetwork && wifiNetworks.indexOf(actionNetwork) < 0) {
            actionError = actionKind === "forget" ? "" : "Network is no longer available";
            clearAction();
        }
    }
    Component.onDestruction: {
        if (scannerDevice) scannerDevice.scannerEnabled = false;
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() { root.syncScanner(); if (!Networking.wifiEnabled) root.clearPassword(); }
        function onWifiHardwareEnabledChanged() { root.syncScanner(); }
    }
    Connections {
        target: root.actionNetwork
        function onConnectedChanged() { root.checkAction(); }
        function onKnownChanged() { root.checkAction(); }
        function onStateChangingChanged() { root.checkAction(); }
        function onConnectionFailed(reason) {
            const network = root.actionNetwork;
            const needsPassword = network && root.usesPsk(network)
                && (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout);
            root.actionError = reason === ConnectionFailReason.NoSecrets ? "Credentials required"
                : reason === ConnectionFailReason.WifiAuthTimeout ? "Wi-Fi authentication timed out"
                : reason === ConnectionFailReason.WifiNetworkLost ? "Network lost" : "Connection failed";
            root.clearAction();
            if (needsPassword && networkPopup.visible) root.promptPassword(network);
        }
    }
    Timer {
        id: actionTimeout
        interval: 35000
        onTriggered: {
            root.actionError = "Network request timed out";
            root.clearAction();
        }
    }
    Process {
        id: sampler
        property int requestGeneration: -1
        property bool startedSuccessfully: false
        onStarted: startedSuccessfully = true
        onRunningChanged: {
            if (!running && !startedSuccessfully && networkPopup.visible && requestGeneration === root.generation)
                root.detailsError = "Could not start network sampler";
        }
        stdout: StdioCollector { id: sampleOutput }
        onExited: (exitCode, exitStatus) => {
            if (!networkPopup.visible || requestGeneration !== root.generation) return;
            try {
                const next = JSON.parse(sampleOutput.text);
                root.updateDetails(next);
                if (exitCode !== 0 || exitStatus !== 0) root.detailsError = next.error || "Network details unavailable";
            } catch (error) {
                root.resetDetails();
                root.detailsError = "Network details unavailable";
            }
        }
    }
    Timer {
        interval: 1500
        repeat: true
        running: networkPopup.visible
        onTriggered: root.refreshDetails()
    }

    width: networkRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: networkMouse.containsMouse || networkPopup.visible ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: "Network"

    component NetworkText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        textFormat: Text.PlainText
    }
    component SectionLabel: NetworkText {
        color: Theme.overlay0
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
    }
    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    component NetworkTooltip: PopupWindow {
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
            NetworkText { id: tooltip; anchors.centerIn: parent; text: tooltipWindow.text; font.pixelSize: Theme.fontSize - 1 }
        }
    }
    component ActionButton: Rectangle {
        id: button
        property string text: ""
        property bool active: false
        signal clicked()
        implicitWidth: label.implicitWidth + 18
        implicitHeight: 26
        radius: height / 2
        color: active ? Theme.blue : mouse.containsMouse || activeFocus ? Theme.surface1 : Theme.surface0
        opacity: enabled ? 1 : 0.45
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        NetworkText {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.active ? Theme.base : Theme.text
            font.pixelSize: Theme.fontSize - 1
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
    component DetailRow: Item {
        id: detailRow
        property string label: ""
        property string value: ""
        property string hint: ""
        width: parent.width
        implicitHeight: Math.max(key.implicitHeight, valueText.implicitHeight)
        NetworkText { id: key; text: detailRow.label; color: Theme.overlay0; font.pixelSize: Theme.fontSize - 1 }
        NetworkText {
            id: valueText
            x: 86
            width: parent.width - x
            text: detailRow.value || "—"
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WrapAnywhere
            font.pixelSize: Theme.fontSize - 1
        }
        MouseArea { id: detailMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        NetworkTooltip {
            anchor.item: detailRow
            visible: detailMouse.containsMouse && !!detailRow.hint && networkPopup.visible
            text: detailRow.hint
        }
    }
    component Metric: Column {
        property string label: ""
        property string value: ""
        property color valueColor: Theme.text
        width: (details.width - 16) / 2
        spacing: 3
        SectionLabel { text: parent.label }
        NetworkText { text: parent.value; color: parent.valueColor }
    }

    Row {
        id: networkRow
        anchors.centerIn: parent
        spacing: 5
        NetworkText {
            text: root.wiredConnected ? "󰈀" : root.activeWifi ? root.signalIcon(root.activeWifi.signalStrength) : "󰤭"
            color: root.wiredConnected || root.activeWifi ? Theme.green : Theme.overlay0
            font.pixelSize: Theme.fontSize + 2
        }
        NetworkText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activeWifi !== null
            width: Math.min(implicitWidth, 110)
            text: root.activeWifi ? root.activeWifi.name : ""
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: networkMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.wifiDevice && Networking.wifiHardwareEnabled) {
                Networking.wifiEnabled = !Networking.wifiEnabled;
                return;
            }
            networkPopup.visible = !networkPopup.visible;
        }
    }

    PopupWindow {
        id: networkPopup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: Math.min(380, screen ? screen.width - 16 : 380)
        implicitHeight: Math.min(details.implicitHeight + 28, screen ? screen.height - Theme.barHeight - 24 : 660)
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            ++root.generation;
            root.syncScanner();
            if (visible) {
                root.resetDetails();
                root.refreshDetails();
                Qt.callLater(() => panel.forceActiveFocus());
            } else {
                sampler.running = false;
                root.clearPassword();
                root.resetDetails();
            }
        }
        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true
            Keys.onEscapePressed: networkPopup.visible = false
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
                    Column {
                        width: parent.width
                        spacing: 6
                        Item {
                            width: parent.width
                            height: 20
                            SectionLabel { anchors.verticalCenter: parent.verticalCenter; text: root.connectionKind }
                            NetworkText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.linkSpeed
                                color: Theme.overlay0
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        NetworkText {
                            width: parent.width
                            text: root.detailNetwork ? root.detailNetwork.name : root.info.iface
                                || (!root.sampled && !root.detailsError ? "Loading…" : "Disconnected")
                            elide: Text.ElideRight
                        }
                        NetworkText {
                            visible: !!root.detailsError || !root.managerAvailable
                            width: parent.width
                            text: root.detailsError || "NetworkManager unavailable"
                            color: Theme.red
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }
                    }
                    Column {
                        visible: !!root.info.iface
                        width: parent.width
                        spacing: 12
                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 10
                            Metric { label: "Ping"; value: root.latency(root.internetSamples); valueColor: root.packetLoss ? Theme.yellow : Theme.text }
                            Metric { label: "Packet loss"; value: root.internetSamples.length ? root.packetLoss + "%" : "—"; valueColor: root.packetLoss ? Theme.yellow : Theme.text }
                            Metric { label: "Receiving"; value: root.receiving < 0 ? "—" : root.bytes(root.receiving) + "/s" }
                            Metric { label: "Sending"; value: root.sending < 0 ? "—" : root.bytes(root.sending) + "/s" }
                            Metric { label: "Downloaded"; value: root.bytes(root.info.rx) }
                            Metric { label: "Uploaded"; value: root.bytes(root.info.tx) }
                        }
                        Divider {}
                        Column {
                            width: parent.width
                            spacing: 6
                            DetailRow { label: "Interface"; value: root.info.iface || ""; hint: "Transfer totals are interface counters since reset" }
                            DetailRow { label: "Address"; value: (root.info.addresses || []).join("\n") }
                            DetailRow { label: "Gateway"; value: root.info.gateway || "" }
                            DetailRow { label: "Router ping"; value: root.latency(root.routerSamples) }
                            DetailRow { label: "DNS"; value: root.info.dnsError || (root.info.dns || []).join("\n") }
                            DetailRow {
                                label: "Probe"
                                value: root.info.pingError || (root.info.internetPing === "unavailable" ? "Unavailable" : "1.1.1.1")
                                hint: "Ping: last 5 replies · loss: last 24 probes"
                            }
                        }
                    }
                    Divider { visible: !!root.wifiDevice || !root.info.iface }
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: !!root.wifiDevice || !root.info.iface
                        Item {
                            width: parent.width
                            height: 26
                            SectionLabel { anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi" }
                            Row {
                                anchors.right: parent.right
                                spacing: 6
                                visible: !!root.wifiDevice
                                ActionButton {
                                    text: root.scanEnabled ? "Scanning" : "Scan"
                                    enabled: Networking.wifiEnabled && Networking.wifiHardwareEnabled
                                    onClicked: root.scanEnabled = !root.scanEnabled
                                }
                                ActionButton {
                                    text: Networking.wifiEnabled ? "On" : "Off"
                                    active: Networking.wifiEnabled
                                    enabled: root.managerAvailable && Networking.wifiHardwareEnabled
                                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                                }
                            }
                        }
                        NetworkText {
                            visible: !root.wifiDevice || !Networking.wifiEnabled || !Networking.wifiHardwareEnabled || !root.wifiNetworks.length
                            text: !root.wifiDevice ? "No Wi-Fi adapter" : !Networking.wifiHardwareEnabled ? "Wi-Fi hardware blocked"
                                : !Networking.wifiEnabled ? "Wi-Fi is off" : "No networks found"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Repeater {
                            model: root.wifiDevice && Networking.wifiEnabled ? root.wifiDevice.networks : null
                            delegate: Item {
                                id: networkItem
                                required property var modelData
                                width: details.width
                                height: 36
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius
                                    color: networkItemMouse.containsMouse || activeFocus ? Theme.surface0 : "transparent"
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.Button
                                    Accessible.name: networkItem.modelData.name + (networkItem.modelData.connected ? ", disconnect" : ", connect")
                                    Keys.onReturnPressed: root.selectNetwork(networkItem.modelData)
                                    Keys.onSpacePressed: root.selectNetwork(networkItem.modelData)
                                    NetworkText {
                                        x: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.signalIcon(networkItem.modelData.signalStrength)
                                        color: networkItem.modelData.connected ? Theme.green : Theme.overlay0
                                    }
                                    NetworkText {
                                        x: 31
                                        width: rowActions.x - x - 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: networkItem.modelData.name || "Hidden network"
                                        elide: Text.ElideRight
                                        color: networkItem.modelData.connected ? Theme.blue : Theme.text
                                    }
                                    MouseArea {
                                        id: networkItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !root.busy && !networkItem.modelData.stateChanging
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.selectNetwork(networkItem.modelData)
                                    }
                                    Row {
                                        id: rowActions
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        NetworkText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.actionNetwork === networkItem.modelData ? (root.actionKind === "connect" ? "Connecting…"
                                                : root.actionKind === "forget" ? "Forgetting…" : "Disconnecting…")
                                                : networkItem.modelData.stateChanging ? "Working…" : networkItem.modelData.connected ? "Disconnect"
                                                : networkItem.modelData.security !== WifiSecurityType.Open && networkItem.modelData.security !== WifiSecurityType.Owe ? "󰌾" : "Join"
                                            color: Theme.overlay0
                                            font.pixelSize: Theme.fontSize - 2
                                        }
                                        ActionButton {
                                            visible: networkItem.modelData.known && !networkItem.modelData.connected
                                            text: "Forget"
                                            enabled: !root.busy && !networkItem.modelData.stateChanging
                                            onClicked: root.runAction(networkItem.modelData, "forget")
                                        }
                                    }
                                }
                            }
                        }
                        NetworkText {
                            visible: !!root.actionError
                            width: parent.width
                            text: root.actionError
                            color: Theme.red
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: !!root.passwordNetwork
                            NetworkText {
                                width: parent.width
                                text: root.passwordNetwork ? "Password · " + root.passwordNetwork.name : ""
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize - 1
                            }
                            Rectangle {
                                width: parent.width
                                height: 30
                                radius: Theme.radius
                                color: Theme.surface0
                                border.color: passwordInput.activeFocus ? Theme.blue : Theme.surface1
                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 9
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    selectionColor: Theme.blue
                                    echoMode: TextInput.Password
                                    clip: true
                                    selectByMouse: true
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    Accessible.name: "Wi-Fi password"
                                    onAccepted: root.submitPassword()
                                    Keys.onEscapePressed: networkPopup.visible = false
                                }
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 6
                                ActionButton { text: "Cancel"; onClicked: root.clearPassword() }
                                ActionButton { text: "Connect"; active: true; enabled: passwordInput.text.length > 0 && !root.busy; onClicked: root.submitPassword() }
                            }
                        }
                    }
                }
            }
        }
    }
}
