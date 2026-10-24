-- E-ink: every animated frame is a panel refresh, and llvmpipe renders on the Kindle's two cores.
hl.config({
  animations = { enabled = false },
  decoration = { blur = { enabled = false }, shadow = { enabled = false } },
  cursor = { no_hardware_cursors = true, inactive_timeout = 3 },
  xwayland = { enabled = false },
  debug = { disable_logs = false, enable_stdout_logs = true },
})
