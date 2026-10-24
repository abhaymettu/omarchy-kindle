#!/bin/bash
# Copy an Omarchy checkout into the device rootfs at /usr/share/omarchy.
# Only the named themes are copied, since all of them come to about 160 MB.
# Usage: install-omarchy.sh OMARCHY_CHECKOUT [THEME...]   (default themes: tokyo-night white)
set -euo pipefail
. "$(dirname "$0")/ssh.sh"
src=${1:?path to an Omarchy checkout}; shift
themes=${*:-tokyo-night white}
excludes=()
for t in "$src"/themes/*/; do
  t=$(basename "$t"); [[ " $themes " == *" $t "* ]] || excludes+=(--exclude="./themes/$t")
done
echo "Omarchy $(git -C "$src" rev-parse --short HEAD 2>/dev/null || echo unknown), themes: $themes"
COPYFILE_DISABLE=1 tar --no-xattrs -czf - -C "$src" --exclude=./.git --exclude=./test --exclude=./manual "${excludes[@]}" . |
  k '/mnt/base-us/omarchy/bin/chroot.sh up && mkdir -p /var/tmp/omarchy/usr/share/omarchy && tar -xzf - -C /var/tmp/omarchy/usr/share/omarchy && sync'
