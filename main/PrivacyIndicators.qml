import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    function nodeMetadata(node) {
        if (node === null) {
            return "";
        }

        const properties = node.properties || {};
        return [
            node.type,
            node.name,
            node.description,
            properties["media.role"],
            properties["media.name"],
            properties["node.name"],
            properties["node.description"],
            properties["application.name"],
            properties["device.api"],
            properties["factory.name"]
        ].filter(value => value).join(" ").toLowerCase();
    }

    function isActive(link) {
        return link !== null
            && link.state === PwLinkState.Active
            && link.source !== null
            && link.target !== null;
    }

    function isMicrophoneLink(link) {
        return isActive(link)
            && link.source.audio !== null
            && !link.source.isSink
            && !link.source.isStream
            && link.target.audio !== null
            && link.target.isStream;
    }

    function isCameraLink(link) {
        if (!isActive(link) || link.source.audio !== null || link.source.isStream) {
            return false;
        }

        const metadata = nodeMetadata(link.source);
        return metadata.includes("video/source")
            || metadata.includes("v4l2")
            || metadata.includes("camera");
    }

    function isScreenShareLink(link) {
        if (!isActive(link) || link.source.audio !== null || !link.source.isStream) {
            return false;
        }

        const metadata = nodeMetadata(link.source);
        return metadata.includes("video") && (
            metadata.includes("screen")
            || metadata.includes("screencast")
            || metadata.includes("desktop")
            || metadata.includes("monitor")
            || metadata.includes("window")
            || metadata.includes("portal")
        );
    }

    readonly property var activeLinks: Pipewire.linkGroups.values.filter(link => isActive(link))
    readonly property bool microphoneActive: activeLinks.some(link => isMicrophoneLink(link))
    readonly property bool cameraActive: activeLinks.some(link => isCameraLink(link))
    readonly property bool screenShareActive: activeLinks.some(link => isScreenShareLink(link))
    readonly property bool anyActive: microphoneActive || cameraActive || screenShareActive

    visible: anyActive
    width: visible ? indicatorRow.implicitWidth : 0
    height: parent.height

    PwObjectTracker {
        objects: Pipewire.nodes.values.concat(Pipewire.linkGroups.values)
    }

    Row {
        id: indicatorRow

        anchors.centerIn: parent
        spacing: 4

        Rectangle {
            visible: root.microphoneActive
            width: 8
            height: 8
            radius: width / 2
            color: Theme.red
        }

        Rectangle {
            visible: root.cameraActive
            width: 8
            height: 8
            radius: width / 2
            color: Theme.peach
        }

        Rectangle {
            visible: root.screenShareActive
            width: 8
            height: 8
            radius: width / 2
            color: Theme.mauve
        }
    }
}
