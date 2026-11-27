# App Store Connect — TestFlight and App Review answers

Copy these into App Store Connect. The site in `site/` is published by GitHub Pages (source: main branch) at https://samuel10tecu-tech.github.io/slide/site/.

## Where things are

- App Store Connect app: **Slide: Ski Tracker** (the name "Slide" is taken; the home-screen name stays "Slide"), Apple ID `6839823198`, SKU `slide-ski-001`, bundle id `ch.geneve.slide.ski` (+ `ch.geneve.slide.ski.liveactivity`).
- TestFlight internal group **Family** gets every build automatically.
- Upload a new build: `TEAM_ID=<team id> bash tooling/testflight.sh` (signs with the Apple ID in Xcode → Settings → Accounts).
- API calls: `op run --env-file=.env.1password -- python3 tooling/asc.py get "/v1/apps/6839823198/builds"`. `.env.1password` holds only 1Password references and stays out of git; it needs PyJWT and cryptography.

## App information

- **Privacy Policy URL:** `https://samuel10tecu-tech.github.io/slide/site/privacy.html`
- **Support URL:** `https://samuel10tecu-tech.github.io/slide/site/support.html`
- **Marketing URL (optional):** `https://samuel10tecu-tech.github.io/slide/site/`
- **Category:** Sports (secondary: Health & Fitness)
- **Age rating:** 4+. Answer "None" to every content question. The freestyle course describes tricks but has no violence, gambling or user-generated content.
- **Content rights:** no third-party content. The tutorial buttons open a YouTube search; Slide hosts no videos.

## App Privacy ("nutrition label")

Choose **Data Not Collected**. Slide has no server, account, analytics or ads. Location and motion are processed on the device. Map tiles and resort names come from Apple's own MapKit and CoreLocation services, which do not count as collection by the developer.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`, so App Store Connect does not ask. Slide uses no encryption beyond what iOS provides.

## TestFlight — Test Information

**Beta App Description**

Slide is an offline ski and snowboard tracker. Press Start at the bottom of the lift and put the phone in your pocket. Slide records speed, distance, vertical and every run, even with the screen locked, and saves the day on the phone. Nothing is uploaded and there is no account.

**What to Test**

Record a real ski day with location set to Always. Check that runs and lifts are split correctly, that the Dynamic Island shows your speed, and that the day appears in History after Stop. Try the voice coach with headphones (Voice tab). Report wrong run counts, gaps in the track or battery problems with a screenshot.

**Feedback email:** your own address.

## App Review notes (for external TestFlight and the App Store)

Slide records ski sessions with GPS. No sign-in is needed.

To see the app with data without skiing: open **Profile** and tap **Sample day**. History, Map and the day detail then show a recorded day at Les Crosets.

Background modes:
- **location** — a ski session keeps running in the pocket with the screen locked. GPS starts with Start and stops with Stop.
- **audio** — the optional voice coach (Voice tab → on) speaks speed, distance and runs through headphones while the phone is locked during a session.

Live Activity shows the current speed on the Lock Screen and Dynamic Island while a session runs.

The freestyle course marks inverted tricks as coach-required and tells riders to learn them on a trampoline or airbag first.
