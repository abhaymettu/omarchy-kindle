#!/bin/bash
# Runs inside okkernel:gcc49: kernel source at /w, objects at /w-obj, live device config at /cfg.
set -euo pipefail
O=/obj
mkdir -p $O
[ -f $O/vmlinux ] || make -C /w mrproper >/dev/null
cp /cfg $O/.config
make -C /w O=$O olddefconfig >/dev/null
diff <(grep -E '^(CONFIG_|# CONFIG_)' /cfg | sort) <(grep -E '^(CONFIG_|# CONFIG_)' $O/.config | sort) > /out/config-drift.diff || true
make -C /w O=$O -j"${JOBS:-8}" vmlinux modules > /out/build.log 2>&1 || { grep -nE 'error|Error' /out/build.log | head -20; exit 1; }
cp $O/Module.symvers $O/.config /out/
echo BUILD_OK
