#!/bin/bash
# Push modules, scripts, bridge and the rootfs image to /mnt/base-us/omarchy, verifying each by checksum.
set -euo pipefail
R=~/code/omarchy-kindle
k() { ssh -o BatchMode=yes -i "$HOME/.ssh/kindle_koreader" -p 2222 root@"${KINDLE_HOST:-KINDLE_HOST}" "$@"; }
D=/mnt/base-us/omarchy
k "mkdir -p $D/modules $D/bin"

put() {  # put LOCAL REMOTE
  k "cat > $2.tmp && sync && mv $2.tmp $2 && sync" < "$1"
  [ "$(k "md5sum $2" | cut -d' ' -f1)" = "$(md5 -q "$1")" ] || { echo "MISMATCH $2"; exit 1; }
  echo "ok $2"
}
for m in hdmi drm vgem; do put $R/out/stage/$m.ko $D/modules/$m.ko; done
put $R/out/stage/SHA256SUMS $D/modules/SHA256SUMS
put $R/device/modules.sh $D/bin/modules.sh
for f in chroot session omarchy-provision drill; do put $R/device/$f.sh $D/bin/$f.sh; done
put $R/bridge/kbridge $D/bin/kbridge
put $R/bridge/kexit $D/bin/kexit
k "mkdir -p /mnt/base-us/extensions/omarchy"
for f in config.xml menu.json; do put $R/kual/omarchy/$f /mnt/base-us/extensions/omarchy/$f; done
k "install -m 755 $D/bin/kbridge /var/tmp/omarchy/usr/local/bin/kbridge && sync"
k "chmod +x $D/bin/*"
tar -C $R/rootfs/overlay -cf - --no-xattrs home usr | k "rm -rf $D/overlay && mkdir -p $D/overlay && tar -xf - -C $D/overlay && sync" && echo "ok $D/overlay"

if [ "${1:-}" = rootfs ]; then
  want=$(docker run --rm -v okroot:/out debian:bookworm-slim md5sum /out/arch.ext4 | cut -d' ' -f1)
  docker run --rm -v okroot:/out debian:bookworm-slim cat /out/arch.ext4.gz | k "gunzip -c > $D/arch.ext4.tmp && sync && mv $D/arch.ext4.tmp $D/arch.ext4 && sync"
  got=$(k "md5sum $D/arch.ext4" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "MISMATCH arch.ext4"; exit 1; }
  echo "ok $D/arch.ext4 $got"
fi
