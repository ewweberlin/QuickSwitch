# QuickSwitch — macOS-style task switcher for Omarchy/Hyprland

A beautiful, themed window/task switcher in the style of the macOS app switcher, built as an
[Omarchy](https://omarchy.org/) shell plugin (QML hosted by the long-running
`omarchy-shell` Quickshell process).

<img width="2248" height="722" alt="screenshot-2026-09-04_03-21-39" src="https://github.com/user-attachments/assets/0e77e772-13e6-4798-ae91-3ad1c6844d77" />




☕ **If you like this project, buy me a coffee** → [paypal.me](https://paypal.me/EwgeniWeber)

## Features

- **SUPER+TAB** opens the switcher.
- A **quick SUPER+TAB tap** jumps straight to the previously used window
  without flashing the overlay; tap again to jump back (like macOS Cmd+Tab).
  The strip only appears once SUPER is held for a moment.
- tap **TAB (or Arrow Keys)** repeatedly while holding SUPER to advance the selection (most-recently-used order, current window skipped). **SUPER+SHIFT+TAB** goes back.
- **Mouse hover** highlights an item once the pointer moves; **click** activates it.
- **SUPER+Q** quits the highlighted app.
- **Release SUPER** to activate the selected window — which switches you to
  that window's **workspace**.
- Every item is a **still window snapshot** (captured when the switcher opens)
  with the **app icon in the top-left corner**, arranged in a horizontal strip
  centered on the screen.
- Password managers, auth prompts and private browsing windows are **never
  captured**; they show the app icon instead.
- Windows on special workspaces (scratchpads) are not listed.
- Compatible with **Omarchy Themes**. 

## Requirements

- Omarchy with the Quickshell shell (`omarchy-shell`)
- Hyprland ≥ 0.56 (Lua config) with the `hyprland-toplevel-export` /
  screencopy support for live previews
- `hyprctl` on PATH

## Installation

Install it from this repository with the official Omarchy tooling:

```sh
omarchy plugin add https://github.com/ewweberlin/QuickSwitch.git --enable
```

This clones the repo into `~/.config/omarchy/plugins/`, and enables it.

Bindings (enables SUPER + TAB) — add this line to `~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/ewweberlin.quickswitch/task-switch-bindings.lua")
```

Restart the shell, reload Hyprland and Bindings:

```sh
omarchy restart shell
hyprctl reload
hyprctl configerrors   # should be clean
hyprctl globalshortcuts
```

The `SUPER + TAB` shortcut should appear in `hyprctl globalshortcuts`.

If you prefer that plugin updates never change your Hyprland config, paste the
contents of `task-switch-bindings.lua` into `bindings.lua` instead of the
`dofile` line.

### Removal

```sh
omarchy plugin remove ewweberlin.quickswitch     # or: provide id interactively
omarchy plugin disable ewweberlin.quickswitch    # disable without deleting
```

`plugin remove` unloads and disables the plugin, then handles each install
flavor: it **unlinks** a symlinked checkout (source stays in place), **deletes**
a cloned install, or **backs up** a plain folder. `plugin add` installs from
git can be updated later with:

```sh
omarchy plugin update ewweberlin.quickswitch
```


## Behavior details

- **SUPER+TAB was already bound** in Omarchy to **"Next workspace"**
  (`hl.dsp.focus e+1`). The bindings file unbinds it first, so SUPER+TAB now
  opens the switcher. While the plugin is disabled or not loaded, SUPER+TAB
  falls back to "Next workspace", so there is never a dead key. The other
  workspace-shortcuts (`SUPER+SHIFT+TAB` outside the switcher, `SUPER+CTRL+TAB`)
  are untouched.
- All in-switcher keys (TAB, SHIFT+TAB, arrows, Q, Esc) live in a Hyprland
  submap named `quickswitch` that is only active while the strip is open, so
  your own SUPER+arrow / SUPER+Q bindings keep working everywhere else.
  **Esc** always leaves the submap, even if the shell has crashed.
- **SUPER+Q** quits the highlighted app only while the switcher is open. For a
  global close-this-window, **SUPER+W** already does that everywhere.
- Releasing SUPER with **no item highlighted / pointer outside** the strip
  (Esc, or clicking empty space) closes without changing focus.
- Colors come from the shell `Color` singleton, so the switcher follows the
  active Omarchy theme automatically.

