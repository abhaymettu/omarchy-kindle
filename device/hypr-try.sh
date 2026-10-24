#!/bin/sh
# On-device bring-up probe: start Hyprland headless on vgem as user omarchy for N seconds, keep the log.
C=/mnt/base-us/omarchy/bin/chroot.sh
M=/var/tmp/omarchy
$C up
chmod 666 /dev/dri/card0 /dev/input/event*
grep -q '^omarchy:' $M/etc/passwd || chroot $M useradd -m -u 1000 -G video,input omarchy
mkdir -p $M/run/user/1000 && chroot $M chown omarchy:omarchy /run/user/1000 && chmod 700 $M/run/user/1000
mkdir -p $M/home/omarchy/.config && cp -r $M/root/.config/hypr $M/home/omarchy/.config/ && chroot $M chown -R omarchy:omarchy /home/omarchy/.config
STRACE=$STRACE chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i HOME=/home/omarchy USER=omarchy PATH=/usr/bin XDG_RUNTIME_DIR=/run/user/1000 \
  LD_LIBRARY_PATH=/usr/local/lib/udev-zero STRACE=$STRACE AQ_TRACE=1 HYPRLAND_TRACE=1 AQ_DRM_DEVICES=/dev/dri/card0 AQ_NO_KMS_REQUIREMENT=1 LIBSEAT_BACKEND=noop LP_NUM_THREADS=2 \
  timeout ${1:-25} ${STRACE:+strace -f -o /tmp/hypr.strace -e trace=openat,ioctl,connect,socket} Hyprland > $M/tmp/hypr.log 2>&1
echo exit=$?
