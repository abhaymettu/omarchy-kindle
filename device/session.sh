#!/bin/sh
# On-device Omarchy session control. Usage: session.sh start [--headless] | kual-start | stop | status | ctl HYPRCTL-ARGS... | run CMD... | exec CMD | about | open-url URL | proof DIR
# Hyprland runs as user omarchy inside the Arch chroot, on vgem, with a headless 1072x1448 output.
# While a session runs, the Kindle UI and KOReader are paused (SIGSTOP) and kbridge owns the panel.
D=/mnt/base-us/omarchy
M=/var/tmp/omarchy
C=$D/bin/chroot.sh
RUN="/run/user/1000"
ENVV="HOME=/home/omarchy USER=omarchy LANG=C.UTF-8 OMARCHY_PATH=/usr/share/omarchy PATH=/usr/share/omarchy/bin:/usr/local/bin:/usr/bin XDG_RUNTIME_DIR=$RUN LD_LIBRARY_PATH=/usr/local/lib/udev-zero"

as_user() { chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i $ENVV "$@"; }
sig() { ls -t $M$RUN/hypr 2>/dev/null | head -1; }
running() { pidof Hyprland >/dev/null 2>&1; }
PAUSED="cvm awesome KPPMainApp luajit"
pause_host() { for p in $PAUSED; do pids=$(pidof $p) && kill -STOP $pids; done; echo "$(date +%s)" > $D/paused; }
resume_host() { for p in $PAUSED; do pids=$(pidof $p) && kill -CONT $pids; done; rm -f $D/paused; }
sweep_chroot() { for d in /proc/[0-9]*; do [ "$(readlink $d/root 2>/dev/null)" = $M ] && kill $1 ${d#/proc/} 2>/dev/null; done; }
start_bridge() {
  setsid chroot $M /usr/bin/env -i PATH=/usr/bin XDG_RUNTIME_DIR=$RUN WAYLAND_DISPLAY=wayland-1 \
    /usr/local/bin/kbridge > $M/tmp/kbridge.log 2>&1 < /dev/null &
}

case "$1" in
start)
  running && { echo "already running"; exit 0; }
  grep -q '^vgem ' /proc/modules || $D/bin/modules.sh load || exit 1
  $C up
  chmod 666 /dev/dri/card0 /dev/input/event*
  grep -q '^omarchy:' $M/etc/passwd || chroot $M useradd -m -u 1000 -G video,input omarchy
  mkdir -p $M$RUN && chroot $M chown omarchy:omarchy $RUN && chmod 700 $M$RUN
  $D/bin/omarchy-provision.sh || exit 1
  setsid sh -c "chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i $ENVV \
    AQ_DRM_DEVICES=/dev/dri/card0 AQ_NO_KMS_REQUIREMENT=1 LIBSEAT_BACKEND=noop LP_NUM_THREADS=2 \
    dbus-run-session start-hyprland > $M/tmp/hypr.log 2>&1" < /dev/null > /dev/null 2>&1 &
  for i in $(seq 1 60); do
    if [ -n "$(sig)" ] && as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl monitors 2>/dev/null | grep -q '^Monitor KINDLE'; then
      [ "$2" = "--headless" ] || { pause_host; start_bridge; setsid $D/bin/kexit > $M/tmp/kexit.log 2>&1 < /dev/null & }
      echo "started"; exit 0
    fi
    sleep 1
  done
  echo "Hyprland did not come up; tail of log:"; tail -5 $M/tmp/hypr.log; exit 1
  ;;
kual-start)
  # KUAL runs inside the framework that start pauses, so the start has to outlive it.
  setsid $0 start > $D/kual-start.log 2>&1 < /dev/null &
  ;;
stop)
  pidof kexit >/dev/null && kill $(pidof kexit)
  pidof kbridge >/dev/null && kill $(pidof kbridge)
  pidof start-hyprland >/dev/null && kill $(pidof start-hyprland)
  running && kill $(pidof Hyprland)
  for i in $(seq 1 10); do running || break; sleep 1; done
  running && kill -9 $(pidof Hyprland)
  # Shell helpers outlive Hyprland, and Quickshell relaunches itself from its SIGTERM handler,
  # so end everything still inside the chroot, then kill what survived.
  sweep_chroot; sleep 2; sweep_chroot -9
  rm -rf $M$RUN/hypr $M$RUN/wayland-*
  [ -f $D/paused ] && resume_host
  echo stopped
  ;;
status)
  running && echo "Hyprland pid $(pidof Hyprland)" || echo "Hyprland not running"
  running && as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl monitors | grep -E '^Monitor|[0-9]+x[0-9]+@'
  ;;
ctl)
  shift; as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl "$@"
  ;;
run)
  shift; as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) WAYLAND_DISPLAY=wayland-1 "$@"
  ;;
open-url)
  running || { echo "session not running"; exit 1; }
  $0 exec "MOZ_ENABLE_WAYLAND=1 firefox --new-tab '$2'"
  ;;
about)
  # Omarchy's About layout (fastfetch with the Omarchy logo) in a centred floating window sized for the panel.
  $0 ctl eval 'omarchy_about_size_rule = hl.window_rule({ match = { class = "org.omarchy.about" }, size = { 1000, 560 } })' >/dev/null
  $0 exec 'foot --app-id=org.omarchy.about -e bash -c "fastfetch; exec sleep infinity"'
  ;;
exec)
  running || { echo "session not running"; exit 1; }
  shift; as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl dispatch "hl.dsp.exec_cmd([[$*]])"
  ;;
proof)
  # Evidence for a remote action: what Hyprland composed, what the panel framebuffer holds, which windows exist.
  out=${2:-/tmp/proof}; mkdir -p $M$out && chroot $M chown omarchy:omarchy $out
  as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl -j clients > $M$out/clients.json
  as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) WAYLAND_DISPLAY=wayland-1 grim $out/hyprland.png
  dd if=/dev/fb0 bs=1072 count=1448 2>/dev/null > $M$out/fb0.y8
  cd $M$out && sha256sum hyprland.png fb0.y8 clients.json
  ;;
esac
