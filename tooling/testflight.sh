#!/usr/bin/env bash
# Archive Slide with a paid Apple Developer team and upload it to App Store Connect (TestFlight).
#
#   TEAM_ID=ABCDE12345 bash tooling/testflight.sh
#
# Settings (environment variables):
#   TEAM_ID       required. The 10-character team id from developer.apple.com → Membership.
#   BUNDLE_ID     optional. Default ch.geneve.slide.ski. The Live Activity gets <BUNDLE_ID>.liveactivity.
#   BUILD_NUMBER  optional. Default: the current UTC time (YYYYMMDDHHMM), so every upload is higher.
#   UPLOAD        optional. 1 (default) uploads to App Store Connect. 0 only writes build/testflight/Slide.ipa.
#   ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID
#                 optional. An App Store Connect API key (.p8). Without it, xcodebuild uses the
#                 Apple ID signed in under Xcode → Settings → Accounts.
#
# Signing is automatic. xcodebuild creates the App IDs, the distribution certificate and the
# profiles the first time (-allowProvisioningUpdates). The app record must already exist in
# App Store Connect with the same bundle id, or the upload is refused.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team id (developer.apple.com → Membership).}"
BUNDLE_ID="${BUNDLE_ID:-ch.geneve.slide.ski}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
UPLOAD="${UPLOAD:-1}"

OUT="$ROOT/build/testflight"
ARCHIVE="$OUT/Slide.xcarchive"
rm -rf "$ARCHIVE" "$OUT/export"
mkdir -p "$OUT"

AUTH=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  : "${ASC_KEY_ID:?ASC_KEY_ID is required with ASC_KEY_PATH}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required with ASC_KEY_PATH}"
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

VERSION=$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \(.*\);/\1/p' Slide.xcodeproj/project.pbxproj | head -1)
echo "=== Slide $VERSION ($BUILD_NUMBER), $BUNDLE_ID, team $TEAM_ID ==="

echo "=== Archive ==="
xcodebuild archive \
  -project Slide.xcodeproj \
  -scheme Slide \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  ${AUTH[@]+"${AUTH[@]}"} \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  SLIDE_BUNDLE_ID="$BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Automatic

if [[ "$UPLOAD" == "1" ]]; then DESTINATION=upload; else DESTINATION=export; fi

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$DESTINATION</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

echo "=== Export ($DESTINATION) ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" \
  -allowProvisioningUpdates \
  ${AUTH[@]+"${AUTH[@]}"}

if [[ "$UPLOAD" == "1" ]]; then
  echo "Uploaded Slide $VERSION ($BUILD_NUMBER). App Store Connect → TestFlight shows it after processing (often 5–30 minutes)."
else
  cp "$OUT"/export/*.ipa "$OUT/Slide.ipa"
  echo "Wrote $OUT/Slide.ipa (not uploaded)."
fi
