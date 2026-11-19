#!/bin/bash
set -euo pipefail
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
xcodebuild -project Feather.xcodeproj -scheme Feather -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$build" \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO build
app="$build/Build/Products/Debug-iphonesimulator/Feather.app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
for family in iPhone iPad; do
  device=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
family=sys.argv[1]
for runtime,devices in sorted(json.load(sys.stdin)["devices"].items(),reverse=True):
    for d in devices:
        if ".iOS-" in runtime and d["name"].startswith(family) and d["isAvailable"]:
            print(d["udid"]); sys.exit()
sys.exit("No available simulator for "+family)' "$family")
  xcrun simctl bootstatus "$device" -b
  xcrun simctl install "$device" "$app"
  result=$(xcrun simctl launch "$device" "$bundle")
  pid=${result##*: }
  ready=false
  for attempt in {1..15}; do
    if xcrun simctl spawn "$device" log show --last 60s --style compact \
      --predicate "processIdentifier == $pid AND subsystem == \"Feather\" AND eventMessage == \"store.root.appeared\"" | grep -q 'store.root.appeared'; then
      ready=true
      break
    fi
    sleep 2
  done
  xcrun simctl terminate "$device" "$bundle"
  xcrun simctl shutdown "$device"
  "$ready" || { echo "$family failed to reach store root" >&2; exit 1; }
done
