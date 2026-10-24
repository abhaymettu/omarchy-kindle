#!/bin/bash
# Build unmodified drivers/video/hdmi.c as a standalone module against the stock-config tree in /obj.
set -euo pipefail
# A fixed path, because the build directory is embedded in the module.
E=/tmp/ext-hdmi
mkdir -p $E
cp /ext/Kbuild /w/drivers/video/hdmi.c "$E"/
make -C /w O=/obj M="$E" modules > /out/hdmi-build.log 2>&1 || { cat /out/hdmi-build.log; exit 1; }
cp "$E"/hdmi.ko /out/modules/
sed "s#\t$E/hdmi\t#\textra/hdmi\t#" "$E"/Module.symvers
