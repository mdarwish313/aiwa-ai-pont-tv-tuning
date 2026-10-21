#!/bin/sh
# Connects to the TV without typing a port. Prints the endpoint on success.
# Order: TV_PORT if given; else the TV's mDNS entry; else the last endpoint that worked.
# Usage: sh scripts/connect.sh        |  TV_PORT=<port> sh scripts/connect.sh
. "$(dirname "$0")/lib.sh"
LAST="$PRIVATE/last-endpoint"

if [ -n "$TV_PORT" ]; then
  TV="$TV_IP:$TV_PORT"
else
  # mDNS is intermittent, so it's only the first choice.
  found=$("$ADB" mdns services 2>/dev/null | grep "$TV_IP" | awk '{print $NF}' | head -1)
  if [ -n "$found" ]; then TV="$found"
  elif [ -f "$LAST" ]; then TV=$(cat "$LAST"); echo "mDNS silent; trying last endpoint $TV"
  fi
fi
[ -n "$TV" ] || { echo "No TV endpoint. Read the port on the TV (Wireless debugging) and run: TV_PORT=<port> sh scripts/connect.sh" >&2; exit 1; }

"$ADB" connect "$TV" | tr -d '\r'
if [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" = device ]; then
  echo "$TV" > "$LAST"
  echo "CONNECTED $TV"
else
  echo "Not connected to $TV. Turn Wireless debugging on, or re-pair once (owner types the code from the TV)." >&2
  exit 1
fi
