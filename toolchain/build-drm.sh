#!/bin/bash
# Live device config plus DRM/vgem as modules, built out of tree at /obj-drm. Fails if anything other
# than module-only options changes, because a built-in change would mean the stock kernel lacks it.
set -euo pipefail
O=/obj-drm
mkdir -p $O
cp /cfg $O/.config
cat >> $O/.config <<'CFG'
CONFIG_DRM=m
CONFIG_DRM_VGEM=m
# CONFIG_DRM_FBDEV_EMULATION is not set
CFG
make -C /w O=$O olddefconfig >/dev/null
for p in /patches/*.patch; do patch -d /w -p1 -N -r - --dry-run -s < "$p" >/dev/null && patch -d /w -p1 -N -s < "$p"; done
norm() { grep -E '^(CONFIG_|# CONFIG_)' "$1" | sort; }
diff <(norm /cfg) <(norm $O/.config) > /out/drm-config.diff || true
cat /out/drm-config.diff
make -C /w O=$O -j"${JOBS:-8}" vmlinux modules > /out/drm-build.log 2>&1 || { grep -nE 'error|Error' /out/drm-build.log | head -20; exit 1; }
mkdir -p /out/modules
find $O/drivers/gpu -name '*.ko' -exec cp {} /out/modules/ \;
cp $O/Module.symvers /out/drm-Module.symvers
ls -la /out/modules
