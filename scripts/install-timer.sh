#!/bin/sh
# macOS: installs the rollback timer (deadman.sh tick every 30 s via launchd).
# launchd cannot run scripts from ~/Documents (privacy protection), so the scripts are copied to a runtime
# folder first. Run this again after editing any script.
# Usage: TV_IP=<tv ip> sh scripts/install-timer.sh        Uninstall: sh scripts/install-timer.sh --remove
set -e
LABEL=com.android-tv-tuning.deadman
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
RUNTIME="${TVTUNE_DATA:-$HOME/.android-tv-tuning}/runtime"

if [ "$1" = --remove ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"; echo "Timer removed."; exit 0
fi
: "${TV_IP:?set TV_IP to the IP address of the TV}"

mkdir -p "$RUNTIME" && chmod 700 "$RUNTIME"
cp "$(dirname "$0")"/*.sh "$RUNTIME/"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$RUNTIME/deadman.sh</string><string>tick</string></array>
  <key>EnvironmentVariables</key><dict><key>TV_IP</key><string>$TV_IP</string></dict>
  <key>StartInterval</key><integer>30</integer>
  <key>StandardErrorPath</key><string>$RUNTIME/../deadman.stderr</string>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Timer installed. Arm windows with: sh $RUNTIME/deadman.sh arm 5 <snapshot>"
