#!/bin/bash
# Build a fresh signed archive on macOS. Supply the ExportOptions.plist from an Xcode device export.
set -euo pipefail
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple team identifier}"
: "${BUNDLE_ID:?Set BUNDLE_ID to the App ID covered by your profile}"
options="${1:?Supply an Xcode ExportOptions.plist}"
out="${2:?Supply a new output directory}"
test -f "$options"
mkdir "$out"
root="$(cd "$(dirname "$0")/.." && pwd)"
archive="$out/Feather.xcarchive"
xcodebuild -project "$root/Feather.xcodeproj" -scheme Feather -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' \
  CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" \
  -exportOptionsPlist "$options" -allowProvisioningUpdates
ipas=("$out"/export/*.ipa)
test "${#ipas[@]}" -eq 1
python3 "$root/scripts/check_device_ipa.py" "${ipas[0]}"
