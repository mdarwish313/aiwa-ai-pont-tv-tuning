#!/bin/sh
# Puts the TV back to a snapshot: disabled packages, HOME role, and the settings keys in the scope file.
# Usage: sh scripts/restore.sh <snapshot_dir> [--dry-run] [--scope <file>]
#   scope file lines: "<namespace> <key>", e.g. "global animator_duration_scale"
# Never uninstalls, never touches a package that the snapshot has enabled and the TV has enabled.
. "$(dirname "$0")/lib.sh"

snap=$1; shift || true
[ -d "$snap" ] || { echo "No snapshot at $snap" >&2; exit 2; }
dry=0; scope=
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --scope) shift; scope=$1 ;;
    *) echo "Unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
require_tv

run() { if [ $dry -eq 1 ]; then echo "DRY: $*"; else tvsh "$@" >/dev/null; fi; }

# 1. Packages: make disabled state match the snapshot.
cur_dis=$(tvsh 'pm list packages -d | sort')
snap_dis=$(sort "$snap/packages_disabled.txt")
printf '%s\n' "$snap_dis" | while read -r line; do
  [ -n "$line" ] || continue
  printf '%s\n' "$cur_dis" | grep -Fqx "$line" || { p=${line#package:}; run pm disable-user --user 0 "$p"; }
done
printf '%s\n' "$cur_dis" | while read -r line; do
  [ -n "$line" ] || continue
  printf '%s\n' "$snap_dis" | grep -Fqx "$line" || { p=${line#package:}; run pm enable --user 0 "$p"; }
done

# 2. HOME role: add the snapshot's holders first, then drop the rest, so the role is never empty.
cur_role=$(tvsh 'cmd role get-role-holders android.app.role.HOME' | tr ' ' '\n' | sort)
snap_role=$(tr ' ' '\n' < "$snap/home_role.txt" | sort | grep -v '^$')
printf '%s\n' "$snap_role" | while read -r p; do
  [ -n "$p" ] || continue
  printf '%s\n' "$cur_role" | grep -Fqx "$p" || run cmd role add-role-holder --user 0 android.app.role.HOME "$p"
done
printf '%s\n' "$cur_role" | while read -r p; do
  [ -n "$p" ] || continue
  printf '%s\n' "$snap_role" | grep -Fqx "$p" || run cmd role remove-role-holder --user 0 android.app.role.HOME "$p"
done

# 3. Settings in scope: write the snapshot value, or delete the key if it was absent.
if [ -n "$scope" ]; then
  while read -r ns key; do
    [ -n "$ns" ] || continue
    want=$(grep -E "^$key=" "$snap/settings_$ns.txt" | head -1 | cut -d= -f2-)
    if [ -z "$want" ] && ! grep -qE "^$key=" "$snap/settings_$ns.txt"; then
      run settings delete "$ns" "$key"
    else
      run settings put "$ns" "$key" "$want"
    fi
  done < "$scope"
fi

[ $dry -eq 1 ] && { echo "Dry run: nothing changed."; exit 0; }

# 4. Verify against the snapshot.
ok=1
[ "$(tvsh 'pm list packages -d | sort')" = "$snap_dis" ] || { echo "MISMATCH: disabled packages"; ok=0; }
[ "$(tvsh 'cmd role get-role-holders android.app.role.HOME' | tr ' ' '\n' | sort | grep -v '^$')" = "$snap_role" ] || { echo "MISMATCH: HOME role"; ok=0; }
if [ -n "$scope" ]; then
  while read -r ns key; do
    [ -n "$ns" ] || continue
    want=$(grep -E "^$key=" "$snap/settings_$ns.txt" | head -1 | cut -d= -f2-)
    got=$(tvsh "settings get $ns $key")
    # An absent key reads back as "null", so it only matches when the snapshot had no value.
    if [ -z "$want" ]; then [ "$got" = null ] || [ -z "$got" ]; else [ "$got" = "$want" ]; fi || { echo "MISMATCH: $ns $key (got '$got', want '$want')"; ok=0; }
  done < "$scope"
fi
[ $ok -eq 1 ] && echo "RESTORED and verified against $snap" || { echo "NOT fully restored; see mismatches above" >&2; exit 1; }
