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
        // Special workspaces (scratchpads) have negative ids; windows parked
        // there are hidden on purpose and must not show up in the switcher.
        if (!c.workspace || c.workspace.id < 0) continue;
        if (c.hidden || c.mapped === false) continue;
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

// Windows whose content must never be screen-captured into a preview card
// (password managers, auth prompts, private browsing). They get the icon
// fallback instead of a snapshot.
const SENSITIVE_CLASS = /keepass|1password|bitwarden|proton.?pass|enpass|pinentry|gcr-prompter|polkit|seahorse|kwallet|secrets|authenticator|signal|veracrypt/i;
const SENSITIVE_TITLE = /private browsing|incognito|inprivate|privates? fenster|privater modus|inkognito|password|passwort|kennwort/i;

function isSensitive(cls, title) {
    return SENSITIVE_CLASS.test(String(cls || "")) || SENSITIVE_TITLE.test(String(title || ""));
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
//
// Only freedesktop icon *names* (no paths, URIs, separators or traversal) may
// be handed to Quickshell.iconPath's themed lookup: an application controls its
// own window class, so a class such as "/tmp/evil.png" would otherwise be
// treated as a direct file source and reach Qt/libpng through the shared
// shell, where retained compressed text metadata has no memory budget. Desktop
// entry icons are a separate, installed source and are intentionally left
// untouched.
function isSafeIconName(value) {
    const s = String(value == null ? "" : value).trim();
    if (!s) return false;
    // No path separators, traversal or URI schemes can reach the filesystem
    // or a QML image provider directly.
    if (s.indexOf("/") !== -1 || s.indexOf("\\") !== -1) return false;
    if (s.indexOf("..") !== -1) return false;
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(s)) return false;
    // Freedesktop icon names are simple identifiers.
    return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(s);
}

function iconPathFor(DesktopEntries, Quickshell, cls, title) {
    const clsLower = String(cls || "").toLowerCase();
    if (isSafeIconName(String(cls || ""))) {
        for (const v of [cls, clsLower, String(cls || "").replace(/-/g, ""), String(cls || "").split(".")[0]]) {
            if (!isSafeIconName(v)) continue;
            const e = DesktopEntries.byId(v);
            if (e && e.icon) return Quickshell.iconPath(e.icon, "application-x-executable");
        }
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

    // Application-controlled class values that are not themselves safe icon names
    // (e.g. absolute paths) must not feed their derived fragments to the themed
    // lookup either; only legitimate, simple class names reach this point.
    if (isSafeIconName(String(cls || ""))) {
        for (const v of [cls, clsLower, String(cls || "").split("-")[0], String(cls || "").split(".").pop()]) {
            if (!isSafeIconName(v)) continue;
            const p = Quickshell.iconPath(v, true);
            if (p) return p;
        }
    }

    return Quickshell.iconPath("application-x-executable");
}
