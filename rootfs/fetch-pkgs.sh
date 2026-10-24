#!/bin/bash
# Download packages (and dependencies) with signature verification against the base image keyring.
set -euo pipefail
sed -i "s/^\[options\]/[options]\nDisableSandbox/" /etc/pacman.conf
pacman-key --init >/dev/null 2>&1; pacman-key --populate archlinuxarm >/dev/null 2>&1
pacman -Syw --noconfirm --cachedir /pkgs "$@" >/dev/null
ls /pkgs
