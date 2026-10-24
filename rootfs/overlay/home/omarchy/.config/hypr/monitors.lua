-- Kindle Basic 2024 panel: one headless 1072x1448 output that kbridge mirrors to the e-ink framebuffer.
hl.monitor({ output = "KINDLE", mode = "1072x1448@10", position = "0x0", scale = 1 })
hl.monitor({ output = "FALLBACK", disabled = true })
hl.env("GDK_SCALE", "1")
