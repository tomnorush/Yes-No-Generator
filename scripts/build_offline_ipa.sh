#!/usr/bin/env bash
# Builds unsigned .ipa files of the Offline configuration, for installing on your own device
# with a sideloading tool (which signs them with your Apple ID). Needs a Mac with Xcode.
# CI runs this too; see .github/workflows/offline-ipa.yml and INSTALL.md.
#
#   scripts/build_offline_ipa.sh [output-dir]      # default: build/
#
# Produces:
#   YesNo-Offline.ipa             iPhone app with the Apple Watch app inside
#   YesNo-Offline-iPhoneOnly.ipa  iPhone app only (for tools or free accounts that can't sign the watch app)
set -euo pipefail

cd "$(dirname "$0")/.."
out="${1:-build}"
archive="$out/YesNo-Offline.xcarchive"
stage="$out/ipa-stage"

rm -rf "$archive" "$stage" "$out"/YesNo-Offline*.ipa
mkdir -p "$out"

xcodebuild archive -quiet \
  -project YesNo.xcodeproj \
  -scheme "YesNo Offline" \
  -configuration Offline \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

app="$archive/Products/Applications/YesNo.app"
if [ ! -d "$app" ]; then
  echo "error: $app was not produced" >&2
  exit 1
fi
if [ ! -d "$app/Watch/YesNoWatch.app" ]; then
  echo "error: the Apple Watch app is missing from $app" >&2
  exit 1
fi

package() { # $1 = output file name
  (cd "$stage" && zip -qry "../$1" Payload)
  echo "Built $out/$1 ($(du -h "$out/$1" | cut -f1))"
}

mkdir -p "$stage/Payload"
cp -R "$app" "$stage/Payload/"
package YesNo-Offline.ipa

rm -rf "$stage/Payload/YesNo.app/Watch"
package YesNo-Offline-iPhoneOnly.ipa

rm -rf "$stage"
