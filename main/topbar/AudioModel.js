function isPlaybackStream(node) {
    if (!node || !node.isStream)
        return false;
    if (node.isSink === true)
        return true;

    const mediaClass = String(node.type || "");
    return mediaClass.indexOf("Stream/Output/Audio") !== -1
        || mediaClass.indexOf("AudioOutStream") !== -1
        || mediaClass.indexOf("Output") !== -1;
}

function isAudioSource(node) {
    if (!node)
        return false;
    if (node.audio)
        return true;

    const mediaClass = String(node.type || "");
    return mediaClass.indexOf("Audio/Source") !== -1
        || mediaClass.indexOf("AudioSource") !== -1
        || mediaClass.indexOf("Source") !== -1;
}

function snapshot(list) {
    return list && list.slice ? list.slice() : [];
}

function nodeProperties(node) {
    return node && node.ready && node.properties ? node.properties : {};
}

function cleanDeviceLabel(text) {
    let label = String(text || "").trim();
    label = label.replace(/^sof-soundwire\s+/i, "");
    label = label.replace(/^built-?in audio\s+/i, "");
    label = label.replace(/\s+Output$/i, "");
    label = label.replace(/\s+Input$/i, "");
    label = label.replace(/\bMicrophones\b/g, "Microphone");
    return label;
}

function nodeLabel(node) {
    if (!node)
        return "Unknown";

    const properties = nodeProperties(node);
    const nickname = cleanDeviceLabel(node.nickname
        || node.nick
        || properties["node.nick"]
        || properties["device.profile.description"]
        || "");
    if (nickname)
        return nickname;

    return cleanDeviceLabel(node.description
        || properties["node.description"]
        || node.name
        || "Unknown");
}

function nodeDescription(node) {
    if (!node)
        return "";

    const properties = nodeProperties(node);
    return String([
        node.name,
        node.description,
        node.nickname,
        properties["device.icon-name"] || "",
        properties["device.product.name"] || "",
        properties["node.description"] || "",
        properties["node.nick"] || ""
    ].join(" ")).toLowerCase();
}

function isHeadphones(node) {
    const description = nodeDescription(node);
    return description.indexOf("headphone") !== -1
        || description.indexOf("headset") !== -1
        || description.indexOf("earbud") !== -1
        || description.indexOf("earphone") !== -1
        || description.indexOf("airpod") !== -1;
}

function sinkIcon(node) {
    if (!node)
        return "󰓃";
    if (isHeadphones(node))
        return "󰋋";

    const description = nodeDescription(node);
    if (description.indexOf("bluetooth") !== -1)
        return "󰂯";
    if (description.indexOf("hdmi") !== -1 || description.indexOf("display") !== -1)
        return "󰍹";
    return "󰓃";
}

function sourceIcon(node) {
    if (!node)
        return "󰍬";

    const description = nodeDescription(node);
    if (description.indexOf("headset") !== -1)
        return "󰋋";
    if (description.indexOf("bluetooth") !== -1)
        return "󰂯";
    if (description.indexOf("webcam") !== -1 || description.indexOf("camera") !== -1)
        return "󰄀";
    return "󰍬";
}

function rawStreamLabel(node) {
    if (!node)
        return "";

    const properties = nodeProperties(node);
    return properties["application.name"]
        || node.description
        || properties["media.name"]
        || properties["node.name"]
        || node.name
        || "";
}

function friendlyStreamLabel(label) {
    const value = String(label || "").trim();
    if (!value)
        return "";
    if (value.toLowerCase() === "spotify")
        return "Spotify";
    return value;
}

function playerLabel(player) {
    if (!player)
        return "";
    return friendlyStreamLabel(player.identity || player.desktopEntry || "");
}

function streamMatchesPlayer(streamLabel, candidateLabel) {
    const stream = friendlyStreamLabel(streamLabel).toLowerCase();
    const candidate = friendlyStreamLabel(candidateLabel).toLowerCase();
    if (!stream || !candidate)
        return false;
    return stream === candidate
        || stream.indexOf(candidate) !== -1
        || candidate.indexOf(stream) !== -1;
}

function streamLabel(node, players, streams) {
    const rawLabel = rawStreamLabel(node);
    if (rawLabel.toLowerCase() !== "audio-src")
        return friendlyStreamLabel(rawLabel) || "Stream";

    const playerList = Array.isArray(players) ? players : [];
    const streamList = Array.isArray(streams) ? streams : [];
    const unmatched = [];

    for (let i = 0; i < playerList.length; i++) {
        const player = playerList[i];
        const label = playerLabel(player);
        if (!label || (!player.isPlaying && !player.canPlay))
            continue;

        let represented = false;
        for (let j = 0; j < streamList.length; j++) {
            const otherLabel = rawStreamLabel(streamList[j]);
            if (otherLabel.toLowerCase() !== "audio-src" && streamMatchesPlayer(otherLabel, label)) {
                represented = true;
                break;
            }
        }
        if (!represented)
            unmatched.push(label);
    }

    return unmatched.length === 1 ? unmatched[0] : friendlyStreamLabel(rawLabel) || "Stream";
}

if (typeof module !== "undefined") {
    module.exports = {
        isPlaybackStream,
        isAudioSource,
        snapshot,
        nodeLabel,
        isHeadphones,
        sinkIcon,
        sourceIcon,
        streamLabel
    };
}
