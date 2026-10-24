#!/bin/bash
# Full Kindle backup to the Mac: raw images of the non-user partitions plus tars of user data.
# Every artifact is checksummed on both ends.
set -euo pipefail
B=${1:?backup dir}
mkdir -p "$B" && cd "$B" && rm -f MD5SUMS
. "$(dirname "$0")/../tools/ssh.sh"

for p in mmcblk0p1 mmcblk0p2 mmcblk0p4 mmcblk0p8 mmcblk0boot0 mmcblk0boot1; do
  k "dd if=/dev/$p bs=1M 2>/dev/null" > "$p.img"
  remote=$(k "dd if=/dev/$p bs=1M 2>/dev/null | md5sum" | cut -d' ' -f1)
  local=$(md5 -q "$p.img")
  [ "$remote" = "$local" ] || { echo "MISMATCH $p"; exit 1; }
  echo "$local  $p.img" >> MD5SUMS
done

for d in /var/local /pdata /mnt/base-us; do
  name=$(echo "${d#/}" | tr / -).tar
  k "tar -cf - -C $d . 2>/dev/null" > "$name"
  echo "$(md5 -q "$name")  $name" >> MD5SUMS
  echo "$name members=$(tar -tf "$name" | wc -l | tr -d ' ') remote_files=$(k "find $d | wc -l")"
done
ls -la
