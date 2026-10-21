#!/bin/sh
# Read-only snapshot of the state a transaction could change. Writes to the private folder only.
# Usage: sh scripts/snapshot.sh <label>   -> prints the snapshot directory
. "$(dirname "$0")/lib.sh"
require_tv

label=${1:-manual}
dir="$SNAPS/$(date +%Y%m%d-%H%M%S)-$label"
mkdir -p "$dir" && chmod 700 "$dir"

tvsh 'getprop ro.product.model; getprop ro.build.version.release; getprop ro.build.version.sdk; grep -E "MemTotal|MemAvailable" /proc/meminfo' > "$dir/props.txt"
tvsh 'pm list packages -d | sort' > "$dir/packages_disabled.txt"
tvsh 'pm list packages -3 | sort' > "$dir/packages_user.txt"
tvsh 'pm list packages -s | sort' > "$dir/packages_system.txt"
tvsh 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1' > "$dir/home_resolved.txt"
tvsh 'cmd role get-role-holders android.app.role.HOME' > "$dir/home_role.txt"
for ns in global secure system; do
  tvsh "settings list $ns | sort" > "$dir/settings_$ns.txt"
done
# A dropped connection gives empty files; a restore from those would re-enable every disabled app.
if [ ! -s "$dir/packages_system.txt" ] || [ ! -s "$dir/home_role.txt" ] || [ ! -s "$dir/settings_global.txt" ]; then
  rm -rf "$dir"; echo "Snapshot failed: the TV returned empty data (offline?). Nothing saved." >&2; exit 1
fi
( cd "$dir" && shasum -a 256 * > SHA256SUMS )
echo "$dir"
