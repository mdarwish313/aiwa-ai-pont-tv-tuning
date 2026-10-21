#!/bin/sh
# Rollback timer for one TV transaction. Runs from launchd every 30 s (tick).
#   arm <minutes> <snapshot_dir> [scope_file]  start a window (before the first change)
#   confirm                                    owner said keep and checks passed: disarm, keep the change
#   status                                     show the window
#   tick                                       what launchd runs
# Without a confirm, the window ends with restore.sh. If the TV is unreachable at the deadline,
# it retries every tick until ADB returns, so it also works after a TV reboot.
. "$(dirname "$0")/lib.sh"

STATE="$PRIVATE/deadman.state"
CONFIRM="$PRIVATE/deadman.confirm"
LOG="$PRIVATE/deadman.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; echo "$*"; }

case $1 in
  arm)
    [ -f "$STATE" ] && { echo "A window is already open. Confirm or let it expire first." >&2; exit 1; }
    mins=$2; snap=$3; scope=$4
    [ -d "$snap" ] || { echo "No snapshot at $snap" >&2; exit 2; }
    [ -n "$TV" ] || { echo "Set TV (run connect.sh) before arming." >&2; exit 1; }
    rm -f "$CONFIRM"
    now=$(date +%s)
    printf 'deadline=%s\nsnapshot=%s\nscope=%s\ntv=%s\n' "$((now + mins * 60))" "$snap" "$scope" "$TV" > "$STATE"
    log "ARMED $mins min, snapshot $snap, tv $TV"
    ;;
  confirm)
    [ -f "$STATE" ] || { echo "No open window." >&2; exit 1; }
    touch "$CONFIRM"
    rm -f "$STATE"
    log "CONFIRMED by owner; window closed, change kept"
    ;;
  status)
    if [ -f "$STATE" ]; then
      dl=$(sed -n 's/^deadline=//p' "$STATE"); left=$((dl - $(date +%s)))
      echo "Open window: ${left}s left. $(sed -n 's/^snapshot=//p' "$STATE")"
    else
      echo "No open window."
    fi
    ;;
  tick)
    [ -f "$STATE" ] || exit 0
    if [ -f "$CONFIRM" ]; then rm -f "$STATE"; log "Confirm marker found; window closed."; exit 0; fi
    dl=$(sed -n 's/^deadline=//p' "$STATE")
    [ "$(date +%s)" -lt "$dl" ] && exit 0
    snap=$(sed -n 's/^snapshot=//p' "$STATE"); scope=$(sed -n 's/^scope=//p' "$STATE")
    TV=$(sed -n 's/^tv=//p' "$STATE"); export TV
    if [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
      "$ADB" connect "$TV" >/dev/null 2>&1
    fi
    if [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
      log "Deadline passed; TV unreachable, will retry."
      exit 0
    fi
    set -- "$snap"; [ -n "$scope" ] && [ "$scope" != "" ] && set -- "$snap" --scope "$scope"
    if sh "$(dirname "$0")/restore.sh" "$@" >> "$LOG" 2>&1; then
      rm -f "$STATE"; log "Deadline passed without confirm: RESTORED from $snap"
    else
      log "Restore reported mismatches; kept window open to retry."
    fi
    ;;
  *) echo "Usage: deadman.sh arm <min> <snapshot> [scope] | confirm | status | tick" >&2; exit 2 ;;
esac
