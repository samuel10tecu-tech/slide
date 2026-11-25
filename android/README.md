# Slide for Android

Kotlin and Jetpack Compose. Same night-alpine ski tracker: GPS in a foreground service, run and lift detection, live OpenStreetMap (osmdroid, no API key), pins for saved days, history, a short freestyle course, audio coach with text-to-speech that ducks music, and GPX share.

English and French interface strings. Debug builds are signed with `slide-debug.keystore` (password `android`, alias `slide`) when that file is present.

```bash
cd android
gradle assembleDebug
```
