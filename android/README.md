# Slide for Android

Kotlin and Jetpack Compose. The same app as Slide for iPhone:

- **Same tracking logic.** `logic/` is a line-by-line port of the iOS detector (GPS filter, descent/lift/rest phases, runs, airtime). `LogicParityTest` runs the iOS checks and opens a `.slide` file written by the iPhone app.
- **Same files.** Days are stored as `.slide` archives (the iOS JSON), so a day moves between an iPhone and an Android phone. GPX export and import too.
- **Same screens.** Tracking (speed ring, live map, stats, recovery), Map (every day in speed colours, pins when zoomed out), History (season, records, day detail with replay and charts, sharing as GPX, image or `.slide`), Freestyle (26 tricks, checklist, notes), Voice (headset coach, launcher shortcuts) and Profile.
- **Same 14 languages.** `tooling/android_strings.py` writes `res/values*/strings_slide.xml` from the iOS String Catalog. Android-only texts are in `tooling/i18n/android_only.py`.
- **Live speed** shows in an ongoing notification while tracking (the iOS Live Activity), which also keeps GPS running with the screen off.

Maps use OpenStreetMap tiles through osmdroid (no API key).

## Build

```bash
cd android
gradle testDebugUnitTest assembleDebug
```

Release bundles for Google Play are signed in CI by the manual "Play bundle" workflow (upload key in GitHub secrets and 1Password).

## Screenshots

`adb shell am start -n ch.geneve.slide/.MainActivity --es slidePreview history --es slideLanguage fr` opens a demo screen with a sample day (`track`, `map`, `history`, `day`, `freestyle`, `trick`, `voice`, `profile`). The "Android screens" workflow captures all of them on an emulator for every pull request that changes the app.
