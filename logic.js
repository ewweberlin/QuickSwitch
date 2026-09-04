// Pure logic for the task switcher — no Quickshell imports so it stays testable.
.pragma library

// MRU order of newly fetched clients: the currently focused window (fhid 0,
// which is the one holding SUPER when the switcher opens) goes to the end so
// the cycle starts on the second-most-recent window, matching the macOS
// Cmd+Tab behavior. Everything else sorts ascending by focusHistoryID.
// Returns the flattened window list in cycle order.
function orderClients(clients) {
    const rest = [];
    let active = null;

    for (const c of clients) {
        if (c.pinned) continue;
        const fhid = c.focusHistoryID === undefined ? 0 : c.focusHistoryID;
        if (fhid === 0) {
            active = c;
            continue;
        }
        rest.push(c);
    }

    rest.sort((a, b) => a.focusHistoryID - b.focusHistoryID);

    const ordered = rest;
    if (active) ordered.push(active);
    return ordered;
}

// Group the cycle-ordered windows by workspace (ascending id), preserving the
// global MRU order within each workspace. Returns [{ id, name, entries }].
function groupByWorkspace(ordered) {
    const groups = [];
    const map = {};

    for (const c of ordered) {
        const wsId = c.workspace.id;
        if (!(wsId in map)) {
            map[wsId] = { id: wsId, name: c.workspace.name, entries: [] };
            groups.push(map[wsId]);
        }
        map[wsId].entries.push(c);
    }

    groups.sort((a, b) => a.id - b.id);
    return groups;
}

// Icon cascade: desktop entry by id variants -> StartupWMClass scan ->
// app Name-substring-of-title scan (Chrome PWAs) -> icon theme variants ->
// generic. Mirrors the icon resolution pattern used elsewhere in Omarchy.
function iconPathFor(DesktopEntries, Quickshell, cls, title) {
    const clsLower = String(cls || "").toLowerCase();
    for (const v of [cls, clsLower, cls.replace(/-/g, ""), cls.split(".")[0]]) {
        if (!v) continue;
        const e = DesktopEntries.byId(v);
        if (e && e.icon) return Quickshell.iconPath(e.icon, "application-x-executable");
    }

    const all = DesktopEntries.applications.values;
    for (const e of all) {
        if (e.startupClass && e.startupClass.toLowerCase() === clsLower && e.icon)
            return Quickshell.iconPath(e.icon, "application-x-executable");
    }

    const titleLower = String(title || "").toLowerCase();
    if (titleLower) {
        for (const e of all) {
            const n = String(e.name || "").toLowerCase();
            if (n && titleLower.includes(n) && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
    }

    for (const v of [cls, clsLower, cls.split("-")[0], cls.split(".").pop()]) {
        if (!v) continue;
        const p = Quickshell.iconPath(v, true);
        if (p) return p;
    }

    return Quickshell.iconPath("application-x-executable");
}
