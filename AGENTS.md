# Working on omarchy-kindle

Read README.md first for what this is and how the pieces fit.

## Rules

- **Upstream stays unmodified.** Hyprland, Aquamarine, Quickshell and Omarchy run as shipped. A
  compatibility problem gets a shim in `compat/`, a setting in `rootfs/overlay/`, or a host-side
  helper in `bridge/`. Never patch or fork them, and never swap Hyprland for another compositor.
- **Kindle overrides go in user config.** Only the files under
  `rootfs/overlay/home/omarchy/.config/` and `rootfs/overlay/usr/` change Omarchy's behavior.
  Omarchy's own config is copied in without overwriting, and the overlay always wins.
- **A claim needs a proof from the device.** "It works" means a `tools/kctl` proof bundle (the
  framebuffer readback in `fb0.png`) or the device's own logs, not a successful build.
- **Build in Docker through `build.sh`.** A new build step goes into `build.sh` so the build stays
  reproducible. Module hashes must keep matching `reference/modules.sha256`, or the change
  explains why they moved and updates the file.

## Device safety

The Kindle runs `panic_on_oops=1`, has 970 MiB of RAM, and is someone's reading device.

- Back up with `device/backup.sh` before the first install and before any change to modules.
- A new or changed kernel module passes `tools/check_imports.py` (run by `build.sh stage`) before
  it is loaded. A symbol missing from the stock kernel, or a CRC mismatch, means stop.
- Never flash a partition, change the boot chain, or write outside `/mnt/base-us/omarchy`,
  `/mnt/base-us/extensions/omarchy` and `/var/tmp/omarchy`.
- KOReader and the Kindle UI must come back after every session. `device/drill.sh N` runs N
  start and exit cycles and checks that. Run it after changing `session.sh` or `kexit.c`.
- Watch memory. A change that adds a process or a bar widget is measured on the device with the
  shell and Firefox both open. The OOM killer on this device takes the whole session down.
- Writing a file under `~/.config/hypr/` while Hyprland runs triggers a reload, which can overrun
  Hyprland's 1.5 s config budget on this CPU. Provisioning copies only changed files for this
  reason. Do not add `hyprctl reload` to startup.

## Layout and conventions

- `device/` scripts run on the Kindle under busybox `sh`. No bashisms, no `sleep` with decimals,
  no GNU-only flags. Inside the chroot, GNU tools are available at `/usr/bin`.
- Mac-side scripts (`build.sh`, `device/push.sh`, `device/backup.sh`, `tools/`) are bash and read
  the SSH target from `.kindle.env` through `tools/ssh.sh`. Never commit addresses or keys.
- Hyprland config is Lua (`hyprland.lua`). Dispatch from scripts with
  `hyprctl dispatch "hl.dsp.exec_cmd([[...]])"`, as `session.sh exec` does.
- Comments explain why, especially which kernel or e-ink limit a line works around.

## Common tasks

| Task | Command |
|---|---|
| Rebuild one piece | `./build.sh TARBALL CONFIG bridge` (any step names) |
| Push scripts, modules and overlay | `device/push.sh` |
| Push a new rootfs image | stop the session, then `device/push.sh rootfs` |
| Start, act, capture | `tools/kctl start`, `tools/kctl exec CMD`, `tools/kctl proof` |
| Hyprland state | `ssh ... /mnt/base-us/omarchy/bin/session.sh ctl clients` |
| Logs | `/var/tmp/omarchy/tmp/{hypr,kbridge,kexit}.log` on the device |
| Exit drill | `ssh ... /mnt/base-us/omarchy/bin/drill.sh 10` |
| Allocation and udev diagnostics | `make -C bridge probes`, then run `gbmprobe` or `udevprobe` in the chroot |
