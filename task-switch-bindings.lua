-- ewweberlin.QuickSwitch — bindings to inject into the Hyprland Lua config
-- (~/.config/hypr/bindings.lua). Hyprland >= 0.56 (Lua config).

-- The "Task switch" description acts as a sentinel for the plugin's
-- binding-present check.

-- SUPER+TAB opens the switcher; repeated presses (while holding SUPER) advance
-- the selection. Previously bound to "Next workspace" (hl.dsp.focus e+1).
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Task switch", hl.dsp.global("ewweberlin.QuickSwitch:next"), { repeating = true })

-- SUPER+Q quits the highlighted app while the switcher is open. It is handled
-- inside the overlay itself (it holds exclusive keyboard focus), so no
-- Hyprland bind is required here. SUPER+W already closes the focused window
-- globally.

-- Keep the overlay from animating in/out jarringly.
hl.layer_rule({ match = { namespace = "ewweberlin.QuickSwitch" }, no_anim = true })
