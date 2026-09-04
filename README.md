# QuickSwitch — macOS-style task switcher for Omarchy/Hyprland

A window/task switcher in the style of the macOS app switcher, built as an
[Omarchy](https://omarchy.org/) shell plugin (QML hosted by the long-running
`omarchy-shell` Quickshell process).

![macOS app switcher concept](https://support.apple.com/library/content/dam/edam/applecare/images/en_US/macos/Big-Sur/macos-big-sur-app-switcher-control-navigation.jpg)

## Features

- **SUPER+TAB** opens the switcher; tap **TAB** repeatedly while holding SUPER
  to advance the selection (most-recently-used order, current window skipped).
- **Left/Right arrows** (and Tab / Shift+Tab, Up/Down) move the selection.
- **Mouse hover** highlights an item; **click** activates it.
- **SUPER+Q** quits the highlighted app (keeping the switcher open; the closed
  window disappears from the strip).
- **Release SUPER** to activate the selected window — which switches you to
  that window's **workspace**.
- Every item is a **still window snapshot** (captured when the switcher opens)
  with the **app icon in the top-left corner**, arranged in a horizontal strip
  centered on the screen. Windows that can't be captured fall back to just their
  app icon.

## Requirements

- Omarchy with the Quickshell shell (`omarchy-shell`)
- Hyprland ≥ 0.56 (Lua config) with the `hyprland-toplevel-export` /
  screencopy support for live previews
- `hyprctl` on PATH

## Installation

The `manifest.json` lives at the repo root (required by `omarchy plugin add`),
with `entryPoints` pointing at `Service.qml`.

```sh
# Local development: link a working copy into the plugin dir and enable it.
ln -sfn "$PWD" ~/.config/omarchy/plugins/ewwe.task-switch
omarchy plugin enable ewwe.task-switch

# ...or from a git remote:
# omarchy plugin add https://github.com/USER/OmarchyPlugins --enable
```

Bindings — add this line to `~/.config/hypr/bindings.lua` so plugin updates
apply without touching your config:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/ewwe.task-switch/task-switch-bindings.lua")
```

Then restart the shell and reload Hyprland:

```sh
omarchy restart shell
hyprctl reload
hyprctl configerrors   # should be clean
hyprctl globalshortcuts
```

The `SUPER + TAB` shortcut should appear in `hyprctl globalshortcuts`.

### Manual test

```sh
hyprctl dispatch 'hl.dsp.global("ewwe.task-switch:next")'   # opens the switcher
```

## Behavior details

- **SUPER+TAB was already bound** in Omarchy to **"Next workspace"**
  (`hl.dsp.focus e+1`). The bindings file unbinds it first, so SUPER+TAB now
  opens the switcher. The other workspace-shortcuts (`SUPER+SHIFT+TAB`,
  `SUPER+CTRL+TAB`) are untouched.
- **SUPER+Q** quits the highlighted app only while the switcher is open. For a
  global close-this-window, **SUPER+W** already does that everywhere.
- Releasing SUPER with **no item highlighted / pointer outside** the strip
  (Esc, or clicking empty space) closes without changing focus.
- Colors come from the shell `Color` singleton, so the switcher follows the
  active Omarchy theme automatically.

## Files

| File                     | Purpose                                        |
|--------------------------|------------------------------------------------|
| `manifest.json`          | Plugin manifest (`kind: service`)              |
| `Service.qml`            | Core overlay, cards, input handling            |
| `logic.js`               | MRU ordering, grouping, icon resolution        |
| `task-switch-bindings.lua` | Hyprland binds to include from `bindings.lua` |
