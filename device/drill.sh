#!/bin/sh
# Start/exit drill: N full sessions, each checked for a clean return to the Kindle UI.
# Usage: drill.sh N. Cycles 5 and 10 exit through kexit's watchdog instead of session.sh stop.
D=/mnt/base-us/omarchy
M=/var/tmp/omarchy
S=$D/bin/session.sh
N=${1:-10}
# The kernel log is a ring buffer, so compare the newest matching line rather than counts.
kill0=$(dmesg | grep "Killed process" | tail -1)
oops0=$(dmesg | grep -iE "oops|BUG:" | tail -1)
reader0=$(pidof luajit | wc -w)
fail=0
for c in $(seq 1 $N); do
  t0=$(date +%s)
  $S start > /dev/null || { echo "cycle $c: start failed"; fail=1; break; }
  bar=no
  for i in $(seq 1 45); do
    $S ctl layers 2>/dev/null | grep -q omarchy-bar && { bar=yes; break; }
    sleep 2
  done
  up=$(( $(date +%s) - t0 ))
  if [ $((c % 5)) = 0 ]; then
    exit_by=watchdog; kill $(pidof start-hyprland) $(pidof Hyprland) 2>/dev/null
    for i in $(seq 1 15); do [ -f $D/paused ] || break; sleep 2; done
  else
    exit_by=stop; $S stop > /dev/null
  fi
  sleep 2
  stopped=0; for p in cvm awesome KPPMainApp luajit; do for q in $(pidof $p); do grep -q "State:.*T" /proc/$q/status && stopped=$((stopped+1)); done; done
  left=0; for d in /proc/[0-9]*; do [ "$(readlink $d/root 2>/dev/null)" = $M ] && left=$((left+1)); done
  avail=$(free -m | awk '/buffers\/cache/ {print $4}')
  ok=yes; [ $bar = yes ] && [ $stopped = 0 ] && [ $left = 0 ] && [ ! -f $D/paused ] && [ -z "$(pidof Hyprland kexit kbridge)" ] || { ok=no; fail=1; }
  echo "cycle $c: ok=$ok up=${up}s bar=$bar exit=$exit_by host_stopped=$stopped chroot_left=$left avail=${avail}MB"
done
kill1=$(dmesg | grep "Killed process" | tail -1); oops1=$(dmesg | grep -iE "oops|BUG:" | tail -1)
[ "$kill1" = "$kill0" ] && new_kill=no || { new_kill=yes; fail=1; }
[ "$oops1" = "$oops0" ] && new_oops=no || { new_oops=yes; fail=1; }
echo "new_oom_kill=$new_kill new_oops=$new_oops reader_procs=$reader0->$(pidof luajit | wc -w) result=$([ $fail = 0 ] && echo PASS || echo FAIL)"
