#!/bin/sh
# Read-only check of the TV against config/desired-disabled.txt and the HOME app.
# Run after every restart. Exit 0 = matches, 1 = something differs.
# Usage: sh scripts/check.sh      (connects through mDNS, or set TV=ip:port)
. "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESIRED="${DESIRED:-$ROOT/config/desired-disabled.txt}"

if [ -z "$TV" ] || [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
  sh "$(dirname "$0")/connect.sh" >/dev/null 2>&1 || { echo "TV not reachable. Turn on Wireless debugging and run scripts/connect.sh."; exit 1; }
  TV=$(sh -c '. "'"$(dirname "$0")"'/lib.sh"; "$ADB" mdns services | grep "'"$TV_IP"'" | awk "{print \$NF}" | head -1')
fi
[ -n "$TV" ] || { echo "No TV endpoint found."; exit 1; }
export TV

desired=$(grep -vE '^\s*(#|$)' "$DESIRED" | sort -u)
disabled=$(tvsh 'pm list packages -d' | sed -n 's/^package://p' | sort -u)

bad=0
echo "HOME: $(tvsh 'cmd role get-role-holders android.app.role.HOME')"
echo "Boot: $(tvsh 'getprop sys.boot_completed')  Uptime: $(tvsh 'uptime' | sed 's/.*up //; s/,.*load.*//')"
missing=$(printf '%s\n' "$desired" | while read -r p; do printf '%s\n' "$disabled" | grep -qx "$p" || echo "$p"; done)
extra=$(printf '%s\n' "$disabled" | while read -r p; do printf '%s\n' "$desired" | grep -qx "$p" || echo "$p"; done)
if [ -n "$missing" ]; then echo "RE-ENABLED (should be off):"; echo "$missing" | sed 's/^/  /'; bad=1; fi
if [ -n "$extra" ]; then echo "DISABLED BUT NOT IN LIST (add to config or re-enable):"; echo "$extra" | sed 's/^/  /'; bad=1; fi
UNINST="$(dirname "$DESIRED")/desired-uninstalled.txt"
if [ -f "$UNINST" ]; then
  installed=$(tvsh 'pm list packages --user 0' | sed -n 's/^package://p' | sort -u)
  back=$(grep -vE '^\s*(#|$)' "$UNINST" | while read -r p; do printf '%s\n' "$installed" | grep -qx "$p" && echo "$p"; done)
  if [ -n "$back" ]; then echo "REINSTALLED (should be uninstalled):"; echo "$back" | sed 's/^/  /'; bad=1; fi
fi
[ $bad -eq 0 ] && echo "OK: all $(printf '%s\n' "$desired" | wc -l | tr -d ' ') listed apps are off, nothing unexpected."
exit $bad
