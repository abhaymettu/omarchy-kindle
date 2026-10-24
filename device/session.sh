#!/bin/sh
# On-device Omarchy session control. Usage: session.sh start | stop | status | ctl HYPRCTL-ARGS... | run CMD...
# Hyprland runs as user omarchy inside the Arch chroot, on vgem, with a headless 1072x1448 output.
D=/mnt/base-us/omarchy
M=/var/tmp/omarchy
C=$D/bin/chroot.sh
RUN="/run/user/1000"
ENVV="HOME=/home/omarchy USER=omarchy PATH=/usr/bin XDG_RUNTIME_DIR=$RUN LD_LIBRARY_PATH=/usr/local/lib/udev-zero"

as_user() { chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i $ENVV "$@"; }
sig() { ls -t $M$RUN/hypr 2>/dev/null | head -1; }
running() { pidof Hyprland >/dev/null 2>&1; }

case "$1" in
start)
  running && { echo "already running"; exit 0; }
  grep -q '^vgem ' /proc/modules || $D/bin/modules.sh load || exit 1
  $C up
  chmod 666 /dev/dri/card0 /dev/input/event*
  grep -q '^omarchy:' $M/etc/passwd || chroot $M useradd -m -u 1000 -G video,input omarchy
  mkdir -p $M$RUN && chroot $M chown omarchy:omarchy $RUN && chmod 700 $M$RUN
  mkdir -p $M/home/omarchy/.config && cp -r $M/root/.config/hypr $M/home/omarchy/.config/ && chroot $M chown -R omarchy:omarchy /home/omarchy/.config
  setsid sh -c "chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i $ENVV \
    AQ_DRM_DEVICES=/dev/dri/card0 AQ_NO_KMS_REQUIREMENT=1 LIBSEAT_BACKEND=noop LP_NUM_THREADS=2 \
    Hyprland > $M/tmp/hypr.log 2>&1" < /dev/null > /dev/null 2>&1 &
  for i in $(seq 1 60); do
    [ -n "$(sig)" ] && as_user env HYPRLAND_INSTANCE_SIGNATURE=$(sig) hyprctl monitors 2>/dev/null | grep -q '^Monitor KINDLE' && { echo "started"; exit 0; }
    sleep 1
  done
  echo "Hyprland did not come up; tail of log:"; tail -5 $M/tmp/hypr.log; exit 1
  ;;
stop)
  running && kill $(pidof Hyprland)
  for i in $(seq 1 10); do running || break; sleep 1; done
  running && kill -9 $(pidof Hyprland)
  rm -rf $M$RUN/hypr $M$RUN/wayland-*
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
esac
