# QuickSwitch — macOS-style task switcher for Omarchy/Hyprland

A window/task switcher in the style of the macOS app switcher, built as an
[Omarchy](https://omarchy.org/) shell plugin (QML hosted by the long-running
`omarchy-shell` Quickshell process).

<img width="2248" height="722" alt="screenshot-2026-09-04_03-21-39" src="https://github.com/user-attachments/assets/0e77e772-13e6-4798-ae91-3ad1c6844d77" />


## Features

- **SUPER+TAB** opens the switcher; tap **TAB** repeatedly while holding SUPER
  to advance the selection (most-recently-used order, current window skipped).
- **Mouse hover** highlights an item; **click** activates it.
- **SUPER+Q** quits the highlighted app (keeping the switcher open; the closed
  window disappears from the strip).
- **Release SUPER** to activate the selected window — which switches you to
  that window's **workspace**.
- Every item is a **still window snapshot** (captured when the switcher opens)
  with the **app icon in the top-left corner**, arranged in a horizontal strip
  centered on the screen. Windows that can't be captured fall back to just their
  app icon.
- Compatible with Omarchy Themes. 

## Requirements

- Omarchy with the Quickshell shell (`omarchy-shell`)
- Hyprland ≥ 0.56 (Lua config) with the `hyprland-toplevel-export` /
  screencopy support for live previews
- `hyprctl` on PATH

## Installation

The plugin is a standard Omarchy manifest plugin: `manifest.json` lives at the
repo root with `entryPoints` pointing at `Service.qml`, and it passes
`omarchy plugin validate`. Install it from this repository with the official
Omarchy tooling:

```sh
omarchy plugin add https://github.com/ewweberlin/QuickSwitch.git --enable
```

This clones the repo into `~/.config/omarchy/plugins/`, validates it against
the manifest schema (refusing anything the shell would reject), and enables it.

### Local development

If you are developing on this checkout, link it in place instead of using
`plugin add` (which refuses to overwrite an existing install):

```sh
ln -sfn "$PWD" ~/.config/omarchy/plugins/ewweberlin.QuickSwitch
omarchy plugin enable ewweberlin.QuickSwitch
```

Saving a file anywhere under `~/.config/omarchy/plugins/` hot-reloads the
plugin; if a change does not apply, force a rescan with
`omarchy-shell shell rescanPlugins`.

### Removal

```sh
omarchy plugin remove ewweberlin.QuickSwitch     # or: provide id interactively
omarchy plugin disable ewweberlin.QuickSwitch    # disable without deleting
```

`plugin remove` unloads and disables the plugin, then handles each install
flavor: it **unlinks** a symlinked checkout (source stays in place), **deletes**
a cloned install, or **backs up** a plain folder. `plugin add` installs from
git can be updated later with:

```sh
omarchy plugin update ewweberlin.QuickSwitch
```

Bindings — add this line to `~/.config/hypr/bindings.lua` so plugin updates
apply without touching your config:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/ewweberlin.QuickSwitch/task-switch-bindings.lua")
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
hyprctl dispatch 'hl.dsp.global("ewweberlin.QuickSwitch:next")'   # opens the switcher
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
