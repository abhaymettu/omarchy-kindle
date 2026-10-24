#!/bin/bash
# Runs privileged in okarch:base (linux/arm/v7). Produces a lean armv7h rootfs at /out/root.
set -euo pipefail
sed -i "s/^\[options\]/[options]\nDisableSandbox/" /etc/pacman.conf
pacman-key --init >/dev/null
pacman-key --populate archlinuxarm >/dev/null
pacman -Sy --noconfirm --needed arch-install-scripts >/dev/null
mkdir -p /out/root
pacstrap -c -G -M /out/root "$@"
pacman --root /out/root -Q > /out/packages.txt
sed -i "s/^\[options\]/[options]\nDisableSandbox/" /out/root/etc/pacman.conf
du -sh /out/root
