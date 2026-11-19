#!/bin/bash
# Repackage a device-signed Xcode .app without changing its signature.
set -euo pipefail
app="${1:?Supply the path to Feather.app}"
output="${2:?Supply the output .ipa path}"
root="$(cd "$(dirname "$0")/.." && pwd)"
test -d "$app"
codesign --verify --deep --strict "$app"
dir="$(dirname "$output")"
work="$(mktemp -d "$dir/.amaryt-package.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir "$work/Payload"
ditto "$app" "$work/Payload/$(basename "$app")"
ditto -c -k --norsrc --keepParent "$work/Payload" "$work/candidate.ipa"
python3 "$root/scripts/check_device_ipa.py" "$work/candidate.ipa"
mv -f "$work/candidate.ipa" "$output"
printf '%s\n' "$output"
