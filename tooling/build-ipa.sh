#!/usr/bin/env bash
# Build an unsigned/ad-hoc Slide.ipa for Sideloadly.
# Requires macOS with Xcode (xcodebuild). Does not need an Apple ID.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not installed. This script must run on a Mac with Xcode." >&2
  exit 2
fi

DERIVED="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData}"
OUT="${IPA_OUTPUT_DIR:-$ROOT/build/ipa}"
mkdir -p "$OUT"

echo "=== Unit tests (iOS Simulator) ==="
# Pick an available iPhone simulator. A missing device should not hide the error.
DEST="$(xcodebuild -project Slide.xcodeproj -scheme Slide -showdestinations 2>/dev/null \
  | sed -n 's/.*{ platform:iOS Simulator, id:\([^,]*\), OS:[^,]*, name:\(iPhone[^}]*\)}.*/\1|\2/p' \
  | head -n 1 || true)"
if [[ -n "$DEST" ]]; then
  SIM_ID="${DEST%%|*}"
  xcodebuild test \
    -project Slide.xcodeproj \
    -scheme Slide \
    -configuration Debug \
    -destination "id=$SIM_ID" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO
else
  echo "No iPhone simulator found. Skipping xcodebuild test." >&2
fi

echo "=== Release device build (unsigned, no Apple ID) ==="
# The iOS 18 SDK rejects an ad-hoc identity ("-"). Sideloadly re-signs the IPA.
xcodebuild build \
  -project Slide.xcodeproj \
  -scheme Slide \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  "DEVELOPMENT_TEAM=" \
  "PROVISIONING_PROFILE_SPECIFIER=" \
  "PROVISIONING_PROFILE="

APP="$(find "$DERIVED" -path '*Release-iphoneos/Slide.app' -type d | head -n 1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Slide.app was not produced." >&2
  exit 1
fi

package() {
  local app_src="$1"
  local zip_dir="$2"
  local ipa_path="$3"
  rm -rf "$zip_dir"
  mkdir -p "$zip_dir/Payload"
  cp -R "$app_src" "$zip_dir/Payload/Slide.app"
  rm -f "$ipa_path"
  (cd "$zip_dir" && zip -qry "$ipa_path" Payload)
}

package "$APP" "$OUT/with-extension" "$OUT/Slide.ipa"

PLAIN="$OUT/plain-app"
rm -rf "$PLAIN"
mkdir -p "$PLAIN"
cp -R "$APP" "$PLAIN/Slide.app"
rm -rf "$PLAIN/Slide.app/PlugIns" "$PLAIN/Slide.app/Extensions"
package "$PLAIN/Slide.app" "$OUT/no-extension" "$OUT/Slide-no-extension.ipa"

if [[ -d /opt/cursor/artifacts ]]; then
  cp -f "$OUT/Slide.ipa" "$OUT/Slide-no-extension.ipa" /opt/cursor/artifacts/
fi

echo "Built:"
ls -lh "$OUT/Slide.ipa" "$OUT/Slide-no-extension.ipa"
if [[ -d "$APP/PlugIns" ]]; then
  echo "Extension embedded:"
  ls "$APP/PlugIns"
else
  echo "No PlugIns folder. Slide.ipa has no Live Activity extension."
fi
