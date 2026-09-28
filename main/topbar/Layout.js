// Pure configuration validation; a bad edit never replaces a working layout.
function parse(raw) {
    const config = JSON.parse(raw);
    if (!config || config.version !== 1) throw new Error("bar.json needs version: 1");
    const seen = {};
    const result = { centerAnchor: config.centerAnchor || "", left: [], center: [], right: [] };
    for (const section of ["left", "center", "right"]) {
        if (!Array.isArray(config[section])) throw new Error(section + " must be an array");
        for (const entry of config[section]) {
            if (!entry || typeof entry.id !== "string" || !/^[a-z][a-z0-9-]*$/.test(entry.id))
                throw new Error("Each module needs a lowercase id, e.g. weather");
            if (entry.enabled !== undefined && typeof entry.enabled !== "boolean")
                throw new Error("enabled must be true or false for " + entry.id);
            if (entry.enabled === false) continue;
            if (seen[entry.id]) throw new Error("Duplicate module id: " + entry.id);
            seen[entry.id] = true;
            if (entry.reveal !== undefined && !["always", "hover"].includes(entry.reveal))
                throw new Error("Invalid reveal mode for " + entry.id);
            if (entry.settings !== undefined && (!entry.settings || typeof entry.settings !== "object" || Array.isArray(entry.settings)))
                throw new Error("settings must be an object for " + entry.id);
            result[section].push({id: entry.id, reveal: entry.reveal || "always", settings: entry.settings || {}});
        }
    }
    if (result.centerAnchor && !result.center.some(entry => entry.id === result.centerAnchor && entry.reveal === "always"))
        throw new Error("centerAnchor must name an always-visible center module");
    return result;
}
if (typeof module !== "undefined") module.exports = {parse};
