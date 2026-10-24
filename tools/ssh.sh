# Sourced by the Mac-side scripts for SSH to the Kindle (dropbear on port 2222, as root).
# Set KINDLE_HOST, and optionally KINDLE_KEY and KINDLE_HOST_FALLBACK, in the environment or in .kindle.env.
R=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -f "$R/.kindle.env" ] && . "$R/.kindle.env"
: "${KINDLE_HOST:?set KINDLE_HOST to the Kindle address, see README}"
KINDLE_KEY=${KINDLE_KEY:-$HOME/.ssh/id_ed25519}
if [ -n "${KINDLE_HOST_FALLBACK:-}" ] && ! nc -z -G 2 "$KINDLE_HOST" 2222 2>/dev/null; then
  KINDLE_HOST=$KINDLE_HOST_FALLBACK
fi
k() { ssh -o BatchMode=yes -o ConnectTimeout=8 -i "$KINDLE_KEY" -p 2222 root@"$KINDLE_HOST" "$@"; }
