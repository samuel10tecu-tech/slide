#!/usr/bin/env bash
# Takes Slide screenshots on a running Android emulator (used by the "Android screens" workflow).
# Usage: bash tooling/android_screens.sh <apk> <out-dir> [language]
set -uo pipefail
APK="$1"
OUT="$2"
LANG_CODE="${3:-en}"
mkdir -p "$OUT"
adb install -r "$APK"
adb shell pm grant ch.geneve.slide android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant ch.geneve.slide android.permission.ACCESS_COARSE_LOCATION || true
adb shell pm grant ch.geneve.slide android.permission.POST_NOTIFICATIONS || true
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
for screen in track map history day freestyle trick voice profile; do
  adb shell am force-stop ch.geneve.slide
  adb shell am start -n ch.geneve.slide/.MainActivity --es slidePreview "$screen" --es slideLanguage "$LANG_CODE" >/dev/null
  sleep 9
  adb exec-out screencap -p > "$OUT/$LANG_CODE-$screen.png"
  echo "captured $LANG_CODE-$screen"
done
adb logcat -d -s AndroidRuntime:E > "$OUT/$LANG_CODE-crashes.txt" || true
adb logcat -d -s SlideMap:I > "$OUT/$LANG_CODE-map-log.txt" || true
