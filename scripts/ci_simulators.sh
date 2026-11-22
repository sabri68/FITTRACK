#!/usr/bin/env bash
# Finds (or creates) an iPhone 15 simulator and an Apple Watch simulator on the newest runtimes.
# Prints two lines: IPHONE_UDID=... and WATCH_UDID=...
set -euo pipefail

latest_runtime() { # $1 = iOS | watchOS
  xcrun simctl list runtimes -j | python3 -c '
import json,sys
plat=sys.argv[1]
rts=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["name"].startswith(plat+" ")]
rts.sort(key=lambda r:[int(x) for x in r["version"].split(".")])
print(rts[-1]["identifier"] if rts else "")' "$1"
}

device_type() { # $1 = preferred name regex list (python), fallback prefix
  xcrun simctl list devicetypes -j | python3 -c '
import json,sys,re
prefs=sys.argv[1].split("|"); prefix=sys.argv[2]
types=json.load(sys.stdin)["devicetypes"]
for p in prefs:
    for t in types:
        if t["name"]==p: print(t["identifier"]); sys.exit()
cands=[t for t in types if t["name"].startswith(prefix)]
print(cands[-1]["identifier"] if cands else "")' "$1" "$2"
}

IOS_RT=$(latest_runtime iOS)
WATCH_RT=$(latest_runtime watchOS)
IPHONE_TYPE=$(device_type "iPhone 15" "iPhone")
WATCH_TYPE=$(device_type "Apple Watch Series 11 (46mm)|Apple Watch Series 11 (42mm)|Apple Watch Series 10 (46mm)|Apple Watch Series 10 (42mm)" "Apple Watch Series")

echo "iOS runtime: $IOS_RT / type: $IPHONE_TYPE" >&2
echo "watchOS runtime: $WATCH_RT / type: $WATCH_TYPE" >&2

IPHONE_UDID=$(xcrun simctl create "FitTrack iPhone 15" "$IPHONE_TYPE" "$IOS_RT")
WATCH_UDID=$(xcrun simctl create "FitTrack Watch" "$WATCH_TYPE" "$WATCH_RT")
echo "IPHONE_UDID=$IPHONE_UDID"
echo "WATCH_UDID=$WATCH_UDID"
