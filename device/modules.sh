#!/bin/sh
# On-device: load or unload the DRM/vgem stack. Usage: modules.sh load|unload|status
# Every step is appended to a synced log so a panic still leaves a trace of the last step.
D=/mnt/base-us/omarchy
LOG=$D/modules.log
step() { echo "$(date '+%F %T') $*" >> $LOG; sync; }

case "$1" in
load)
  cd $D/modules && sha256sum -c SHA256SUMS >> $LOG 2>&1 || { step "checksum FAIL"; exit 1; }
  for m in hdmi drm vgem; do
    grep -q "^$m " /proc/modules && continue
    step "insmod $m"
    insmod $D/modules/$m.ko || { step "insmod $m FAILED rc=$?"; dmesg | tail -20 >> $LOG; exit 1; }
    step "insmod $m ok"
  done
  dmesg | grep -iE 'drm|vgem|hdmi' | tail -10 >> $LOG
  ls -la /dev/dri >> $LOG 2>&1
  step "load done"
  ;;
unload)
  for m in vgem drm hdmi; do grep -q "^$m " /proc/modules && { rmmod $m && step "rmmod $m ok" || step "rmmod $m FAILED"; }; done
  ;;
status)
  grep -E '^(hdmi|drm|vgem) ' /proc/modules; ls -la /dev/dri 2>&1; tail -15 $LOG
  ;;
esac
