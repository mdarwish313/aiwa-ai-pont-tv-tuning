# Shared settings for the TV scripts. Sourced, not run.
# TV_IP is required: export TV_IP=<your TV's IP address> (give the TV a fixed address on your router).
ADB="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
TV_IP="${TV_IP:?set TV_IP to the IP address of the TV, e.g. export TV_IP=192.168.1.50}"
# Snapshots and the rollback timer's state. Keep this outside synced folders (iCloud/Dropbox).
PRIVATE="${TVTUNE_DATA:-$HOME/.android-tv-tuning}"
SNAPS="$PRIVATE/snapshots"
mkdir -p "$SNAPS" && chmod 700 "$PRIVATE"
# Set by connect.sh; ip:port of the TV's Wireless debugging endpoint.
TV="${TV:-}"

# </dev/null: adb shell reads stdin, which would swallow the rest of a `while read` loop.
tvsh() { "$ADB" -s "$TV" shell "$@" </dev/null | tr -d "\r"; }

require_tv() {
  if [ -z "$TV" ] || [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
    echo "TV not connected. Run scripts/connect.sh first." >&2
    exit 1
  fi
}
