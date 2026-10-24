#!/bin/sh
# On-device: mount the Arch image at /var/tmp/omarchy (idempotent) and run a command inside it.
# Usage: chroot.sh up | down | run CMD...
D=/mnt/base-us/omarchy
M=/var/tmp/omarchy
up() {
  mountpoint -q $M && return 0
  mkdir -p $M
  mount -o loop,noatime $D/arch.ext4 $M || exit 1
  for f in proc sys dev dev/pts dev/shm; do mount --bind /$f $M/$f; done
  mount -t tmpfs -o size=128m tmpfs $M/tmp
  mkdir -p $M/run/user/0 && chmod 700 $M/run/user/0
  cp /etc/resolv.conf $M/etc/resolv.conf 2>/dev/null
}
down() {
  for f in tmp dev/shm dev/pts dev sys proc ""; do mountpoint -q $M/$f && umount $M/$f; done
}
case "$1" in
up) up ;;
down) down ;;
run) up; shift; exec chroot $M /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/bin:/usr/bin XDG_RUNTIME_DIR=/run/user/0 "$@" ;;
esac
