#!/bin/sh
# Seeds user omarchy with Omarchy's shipped configs, the Kindle overrides and a theme.
# Idempotent: Omarchy's config is copied without overwriting, the Kindle overlay always wins,
# and the theme is set only when none is set yet. Needs the chroot up and /usr/share/omarchy installed.
D=/mnt/base-us/omarchy
M=/var/tmp/omarchy
H=$M/home/omarchy
THEME=${THEME:-Tokyo Night}

[ -d $M/usr/share/omarchy/config ] || { echo "Omarchy not installed at /usr/share/omarchy"; exit 1; }
mkdir -p $H/.config
chroot $M /usr/bin/cp -r --update=none /usr/share/omarchy/config/. /home/omarchy/.config/ || exit 1
# Copy only what changed: Hyprland reloads its Lua config on every write, and a reload on a busy CPU
# overruns Hyprland's fixed 1.5 s config-reload budget.
(cd $D/overlay && find . -type f) | while read -r f; do
  cmp -s "$D/overlay/$f" "$M/$f" || { mkdir -p "$(dirname "$M/$f")" && cp "$D/overlay/$f" "$M/$f"; }
done
chroot $M chown -R omarchy:omarchy /home/omarchy
[ -f $H/.config/omarchy/branding/about.txt ] || { mkdir -p $H/.config/omarchy/branding && cp $M/usr/share/omarchy/icon.txt $H/.config/omarchy/branding/about.txt && chroot $M chown -R omarchy:omarchy /home/omarchy/.config/omarchy; }
mkdir -p $M/etc/fastfetch && cp $M/usr/share/omarchy/etc/fastfetch/config.jsonc $M/etc/fastfetch/
ln -sf /usr/share/zoneinfo/${TZONE:-America/Chicago} $M/etc/localtime

if [ ! -s $H/.local/state/omarchy/current/theme.name ]; then
  chroot $M /usr/bin/setpriv --reuid=1000 --regid=1000 --init-groups /usr/bin/env -i \
    HOME=/home/omarchy USER=omarchy OMARCHY_PATH=/usr/share/omarchy PATH=/usr/share/omarchy/bin:/usr/bin \
    XDG_RUNTIME_DIR=/run/user/1000 OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "$THEME"
fi
sync
echo "theme: $(cat $H/.local/state/omarchy/current/theme.name 2>/dev/null)"
