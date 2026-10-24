#!/bin/bash
# Runs privileged in okarch:base (linux/arm/v7). Produces the armv7h rootfs at /out/root from /packages.txt.
set -euo pipefail
sed -i "s/^\[options\]/[options]\nDisableSandbox/" /etc/pacman.conf
pacman-key --init >/dev/null
pacman-key --populate archlinuxarm >/dev/null
pacman -Sy --noconfirm --needed arch-install-scripts >/dev/null
mkdir -p /out/root
pacstrap -c -M /out/root $(grep -v '^#' /packages.txt)
pacman --root /out/root -Q > /out/packages.lock
# useradd -m fails to copy /etc/skel under QEMU, so the home is made by hand.
useradd --root /out/root -M -d /home/omarchy -u 1000 -G video,input -s /usr/bin/bash omarchy
rm -rf /out/root/home/omarchy && cp -a /out/root/etc/skel /out/root/home/omarchy
chown -R 1000:1000 /out/root/home/omarchy && chmod 700 /out/root/home/omarchy
sed -i "s/^\[options\]/[options]\nDisableSandbox/" /out/root/etc/pacman.conf
du -sh /out/root
