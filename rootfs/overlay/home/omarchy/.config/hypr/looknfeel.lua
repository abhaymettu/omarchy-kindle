-- E-ink: every animated frame is a panel refresh, and llvmpipe renders on the Kindle's two cores.
hl.config({
  animations = { enabled = false },
  decoration = { blur = { enabled = false }, shadow = { enabled = false } },
  cursor = { no_hardware_cursors = true, inactive_timeout = 3 },
  xwayland = { enabled = false },
  debug = { disable_logs = false, enable_stdout_logs = true },
  -- A full Omarchy config reload overruns Hyprland's fixed 1.5 s budget whenever the CPU is busy,
  -- so the config loads once at start instead of on every file change.
  misc = { disable_autoreload = true },
})

-- Omarchy's translucent terminals let the window below bleed through, which e-ink renders as ghost text.
o.window({ tag = "transparent-window" }, { opacity = "1.0 override 1.0 override" })
