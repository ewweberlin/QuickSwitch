import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "logic.js" as Logic

Item {
    id: root

    readonly property string shortAppId: "ewweberlin.quickswitch"

    property bool open: false
    property var windows: []
    property var groups: []
    property int selected: 0
    property bool sawKeyEvent: false
    property bool modsHeld: false
    property string pendingAddr: ""

    function next() { if (windows.length) selected = (selected + 1) % windows.length }
    function prev() { if (windows.length) selected = (selected + windows.length - 1) % windows.length }

    function openSwitcher() {
        console.log("[task-switch] openSwitcher called")
        clientsProc.running = true
    }

    function close(doFocus) {
        if (!open) return
        const entry = (doFocus && windows.length) ? windows[selected] : null
        open = false
        if (!entry) return
        pendingAddr = entry.address
        focusTimer.start()
    }

    Timer {
        id: focusTimer
        interval: 110
        onTriggered: {
            if (root.pendingAddr)
                Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.pendingAddr + '" })')
            root.pendingAddr = ""
        }
    }

    // SUPER+Q quits the highlighted app but keeps the switcher open (SUPER is
    // still held). We close via the Lua dispatcher (matches Omarchy's own
    // close-all helper) and then re-fetch the window list so the closed window
    // disappears; focus is only switched on SUPER release.
    function quitSelected() {
        const entry = windows.length ? windows[selected] : null
        if (!entry || !entry.address) return
        const addr = entry.address
        console.log("[task-switch] quitSelected addr=", addr, "cls=", entry.cls)
        quitProc.command = ["hyprctl", "dispatch",
            'hl.dsp.window.close({ window = "address:' + addr + '" })']
        quitProc.running = true
    }

    Process {
        id: quitProc
        stdout: StdioCollector { onStreamFinished: console.log("[task-switch] quit stdout:", text.trim()) }
        stderr: StdioCollector { onStreamFinished: console.log("[task-switch] quit stderr:", text.trim()) }
        onExited: {
            console.log("[task-switch] quitProc exited code=", exitCode)
            refreshAfterQuit.running = true
        }
    }

    // Keep the overlay mounted (open stays true) and refresh the list.
    Timer {
        id: refreshAfterQuit
        interval: 220
        onTriggered: {
            if (root.open) root.openSwitcher()
        }
    }

    // Keep the Qt-side toplevel model in sync with the compositor so that
    // reloaded/reopened windows map to a current (fresh) wayland handle. Without
    // a refresh, Hyprland.toplevels still holds the sealed toplevel of the
    // pre-reload window, so its new address isn't found and the preview reuses
    // a stale (dead) handle.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "changefloatingmode":
            case "movewindow":
                Hyprland.refreshToplevels()
                break
            }
        }
    }

    GlobalShortcut {
        appid: root.shortAppId
        name: "next"
        onPressed: {
            if (root.open) {
                root.sawKeyEvent = true
                root.modsHeld = true
                root.next()
            } else {
                root.openSwitcher()
            }
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients = []
                try { clients = JSON.parse(text) } catch (e) { return }
                fillWindows(clients)
            }
        }
    }

    function fillWindows(clients) {
        console.log("[task-switch] fillWindows called, n=", Array.isArray(clients) ? clients.length : "not-array")
        if (!Array.isArray(clients)) return
        const ordered = Logic.orderClients(clients)
        if (!ordered.length) return

        const byAddr = {}
        for (const tl of (Hyprland.toplevels.values || [])) {
            const ipc = tl.lastIpcObject
            if (ipc && ipc.address) byAddr[ipc.address] = tl
        }

        const cache = {}
        for (const w of root.windows) cache[w.address] = w

        const records = []
        for (const c of ordered) {
            const addr = c.address
            const tl = byAddr[addr]
            const prev = cache[addr]
            const rec = prev && !prev.dead ? prev : {
                address: addr,
                cls: c.class || c.initialClass || "",
                title: c.title || "-",
                workspaceId: c.workspace ? c.workspace.id : -1,
                workspaceName: c.workspace ? c.workspace.name : "-",
                fhid: c.focusHistoryID === undefined ? 0 : c.focusHistoryID,
                dead: false,
                handle: null
            }
            rec.handle = tl ? tl.wayland : null
            rec.title = c.title || "-"
            rec.cls = c.class || c.initialClass || ""
            rec.workspaceId = c.workspace ? c.workspace.id : rec.workspaceId
            rec.workspaceName = c.workspace ? c.workspace.name : rec.workspaceName
            records.push(rec)
        }

        root.windows = records
        root.groups = Logic.groupByWorkspace(ordered)
        root.selected = 0
        root.sawKeyEvent = false
        root.modsHeld = false
        root.open = true
    }

    function iconPathFor(cls, title) {
        return Logic.iconPathFor(DesktopEntries, Quickshell, cls, title)
    }

    LazyLoader {
        id: loader
        active: root.open
        PanelWindow {
            id: panel

                property bool mouseInside: true
                property bool hoverArmed: false
                property point initialPos: Qt.point(-1, -1)

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                WlrLayershell.namespace: root.shortAppId
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }

                function activate() { root.close(panel.mouseInside) }

                Timer {
                    id: noKeyTimer
                    interval: 150
                    repeat: true
                    running: true
                    onTriggered: {
                        if (root.sawKeyEvent) {
                            if (root.modsHeld) stop()
                            else panel.activate()
                        } else {
                            modCheck.running = true
                        }
                    }
                }

                Process {
                    id: modCheck
                    command: ["hyprctl", "eval",
                        'error(tostring(hl.is_key_down("Super_L") or hl.is_key_down("Super_R")))']
                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (!root.open || root.sawKeyEvent) return
                            if (!text.trim().endsWith("true"))
                                panel.activate()
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Color.menu.scrim
                }

                // Clicking empty space dismisses without switching focus.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close(false)
                }

                // Centered horizontal strip (macOS app-switcher style).
                Item {
                    id: stripWrap
                    anchors.centerIn: parent
                    implicitWidth: strip.implicitWidth
                    implicitHeight: strip.implicitHeight
                    focus: true
                    Keys.priority: Keys.BeforeItem

                    BorderSurface {
                        id: stripBg
                        anchors.fill: strip
                        radius: Style.cornerRadius
                        color: Color.popups.background
                        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)
                    }

                    Row {
                        id: strip
                        anchors.centerIn: parent
                        padding: Style.spacing.panelPadding
                        spacing: Style.spacing.panelPadding
                        z: 2

                        Repeater {
                            model: root.windows

                            delegate: Item {
                                required property int index
                                readonly property var win: root.windows[index]
                                readonly property bool isSelected: root.selected === index

                                width: 180
                                height: 130

                                scale: (isSelected || hover.hovered) ? 1.05 : 1.0
                                opacity: isSelected ? 1.0 : 0.85
                                transformOrigin: Item.Center

                                Behavior on scale {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                }

                                BorderSurface {
                                    id: frame
                                    anchors.fill: parent
                                    radius: Style.cornerRadius
                                    color: Color.popups.background
                                    clip: true
                                    borderSpec: Border.surfaceSpec(
                                        "popups", "border",
                                        isSelected || hover.hovered ? Color.menu.selectedBorder : Color.popups.border,
                                        Style.normalBorderWidth)

                                    // Omarchy selection/hover affordance: a subtle
                                    // fill highlight instead of a hard-coded border.
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: isSelected || hover.hovered
                                        color: Color.menu.selectedBackground
                                    }

                                    // Snapshot taken while the switcher opens. The
                                    // screencopy recording context takes a moment to
                                    // establish, and its first delivered buffer is
                                    // often empty/uninitialized. So: keep requesting
                                    // frames while open, and once the first content
                                    // frame arrives keep grabbing a short "settle"
                                    // burst so a real (populated) frame replaces the
                                    // blank one, then freeze. Cards are recreated
                                    // fresh on every open (the panel is torn down when
                                    // closed), so there is no cache across opens.
                                    ScreencopyView {
                                        id: thumb
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        z: 3
                                        captureSource: win ? win.handle : null
                                        live: false
                                        paintCursor: false
                                        visible: win && win.handle && hasContent

                                        // Whether a real snapshot has been frozen for
                                        // this open. Reset automatically because the
                                        // card is recreated fresh on each open.
                                        property bool frozen: false
                                        property int settleTicks: 0

                                        // Grab a frame as soon as a source is set
                                        // (kicks off context setup immediately).
                                        onCaptureSourceChanged: {
                                            if (thumb.captureSource) {
                                                thumb.captureFrame()
                                                thumb.settleTicks = 0
                                                thumb.frozen = false
                                            }
                                        }

                                        // Runs whenever the switcher is open and a
                                        // source exists — driver via a bound
                                        // `running`, so a freshly-added window whose
                                        // onCaptureSourceChanged may not fire still
                                        // gets captured. Stops after a settle burst
                                        // once real content is present.
                                        Timer {
                                            id: grabber
                                            interval: 90
                                            repeat: true
                                            running: root.open && !!thumb.captureSource && !thumb.frozen
                                            onTriggered: {
                                                thumb.captureFrame()
                                                if (thumb.hasContent) {
                                                    thumb.settleTicks += 1
                                                    if (thumb.settleTicks >= 4) {
                                                        thumb.frozen = true
                                                        thumb.settleTicks = 0
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Fallback while content loads / when a window
                                    // can't be captured: dim area + centered icon.
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.alpha(Color.foreground, 0.05)
                                    }

                                    Rectangle {
                                        id: captureFallback
                                        anchors.fill: parent
                                        visible: !thumb.visible
                                        color: Color.popups.background

                                        Image {
                                            anchors.centerIn: parent
                                            width: 44
                                            height: 44
                                            sourceSize.width: 44
                                            sourceSize.height: 44
                                            fillMode: Image.PreserveAspectFit
                                            source: win ? root.iconPathFor(win.cls, win.title) : ""
                                        }
                                    }

                                    Rectangle {
                                        id: iconBadge
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: Style.spacing.md
                                        width: 34
                                        height: 34
                                        radius: Style.cornerRadius
                                        color: "transparent"
                                        z: 4

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            sourceSize.width: 24
                                            sourceSize.height: 24
                                            fillMode: Image.PreserveAspectFit
                                            source: win ? root.iconPathFor(win.cls, win.title) : ""
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: hover
                                    onHoveredChanged: {
                                        if (hovered) root.selected = index
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        root.selected = index
                                        root.close(true)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: titleLabel
                        anchors.horizontalCenter: strip.horizontalCenter
                        anchors.top: strip.bottom
                        anchors.topMargin: Style.spacing.xl
                        width: Math.min(strip.implicitWidth, 640)
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: root.windows.length ? root.windows[root.selected].title : ""
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                    }

                    // Keyboard navigation. The exclusive keyboard grab keeps
                    // keyboard events flowing here while SUPER is held. Any key
                    // reaching here means SUPER is still held (otherwise the
                    // release/noKeyTimer path would have already closed it), so
                    // mark the modifier as held for every key press.
                    Keys.onPressed: (event) => {
                        root.sawKeyEvent = true
                        root.modsHeld = true
                        if (event.key === Qt.Key_Escape) {
                            root.close(false)
                            event.accepted = true
                            return
                        }
                        // SUPER+Q quits the highlighted app. Being inside the
                        // exclusive grab already means SUPER is held, so don't
                        // rely on event.modifiers (which isn't reliably set).
                        if (event.key === Qt.Key_Q || event.key === Qt.Key_q) {
                            root.quitSelected()
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                            root.next()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                            root.prev()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            panel.activate()
                            event.accepted = true
                        }
                    }

                    Keys.onReleased: (event) => {
                        root.sawKeyEvent = true
                        const superReleasing = event.key === Qt.Key_Meta
                            || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R
                        const superHeld = (event.modifiers & Qt.MetaModifier) && !superReleasing
                        root.modsHeld = !!superHeld
                        if (!root.modsHeld)
                            panel.activate()
                    }

                    HoverHandler {
                        onHoveredChanged: panel.mouseInside = hovered
                    }

                    Component.onCompleted: forceActiveFocus()
                }
            }
    }
}
