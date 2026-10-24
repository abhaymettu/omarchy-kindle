#!/bin/bash
# Pack /out/root into a sparse ext4 image mountable by kernel 4.9, then gzip it for transfer.
set -euo pipefail
apt-get -qq update >/dev/null && apt-get install -y -qq e2fsprogs >/dev/null 2>&1
rm -f /out/arch.ext4 /out/arch.ext4.gz
truncate -s 3G /out/arch.ext4
mke2fs -q -t ext4 -L omarchy -O ^orphan_file,^metadata_csum_seed,^large_dir,^stable_inodes -d /out/root /out/arch.ext4
e2fsck -fn /out/arch.ext4 | tail -1
dumpe2fs -h /out/arch.ext4 2>/dev/null | grep -i features
md5sum /out/arch.ext4
gzip -1 -c /out/arch.ext4 > /out/arch.ext4.gz
ls -la /out/arch.ext4.gz
