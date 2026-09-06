-- ewweberlin.quickswitch — bindings to inject into the Hyprland Lua config
-- (~/.config/hypr/bindings.lua). Hyprland >= 0.56 (Lua config).

-- The "Task switch" description acts as a sentinel for the plugin's
-- binding-present check.

-- SUPER+TAB opens the switcher; repeated presses (while holding SUPER) advance
-- the selection. Previously bound to "Next workspace" (hl.dsp.focus e+1).
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Task switch", hl.dsp.global("ewweberlin.quickswitch:next"), { repeating = true })

-- SUPER + Arrows cycle the switcher selection while it is open. The defaults
-- in tiling.lua bind these to "Focus on left/right/above/below window", which
-- consumes the events before they reach the overlay's exclusive keyboard grab.
-- We unbind + rebind as GlobalShortcuts; when the switcher is closed the
-- handler re-dispatches the original focus command.
hl.unbind("SUPER + LEFT")
o.bind("SUPER + LEFT", "Focus on left window", hl.dsp.global("ewweberlin.quickswitch:focus-left"), { repeating = true })

hl.unbind("SUPER + RIGHT")
o.bind("SUPER + RIGHT", "Focus on right window", hl.dsp.global("ewweberlin.quickswitch:focus-right"), { repeating = true })

hl.unbind("SUPER + UP")
o.bind("SUPER + UP", "Focus on above window", hl.dsp.global("ewweberlin.quickswitch:focus-up"), { repeating = true })

hl.unbind("SUPER + DOWN")
o.bind("SUPER + DOWN", "Focus on below window", hl.dsp.global("ewweberlin.quickswitch:focus-down"), { repeating = true })

-- SUPER+Q quits the highlighted app while the switcher is open. It is handled
-- inside the overlay itself (it holds exclusive keyboard focus), so no
-- Hyprland bind is required here. SUPER+W already closes the focused window
-- globally.

-- Keep the overlay from animating in/out jarringly.
hl.layer_rule({ match = { namespace = "ewweberlin.quickswitch" }, no_anim = true })
