# Slide

Offline ski and freestyle tracker for iPhone (iOS 17+). No account and no server. Days stay on the phone. Fourteen languages, including English and French.

Install without Xcode: **Sideloadly** on Windows and a **free Apple ID**. The files are on the [v1.0 release](https://github.com/samuel10tecu-tech/slide/releases/tag/v1.0).

1. Download [Slide.ipa](https://github.com/samuel10tecu-tech/slide/releases/download/v1.0/Slide.ipa). If Sideloadly refuses the Live Activity extension, use [Slide-no-extension.ipa](https://github.com/samuel10tecu-tech/slide/releases/download/v1.0/Slide-no-extension.ipa). The speed on the Dynamic Island is the only thing you lose.
2. On Windows, install **iTunes** and **iCloud** from Apple’s website, not the Microsoft Store. Install **Sideloadly** from https://sideloadly.io/.
3. Plug in the iPhone, unlock it, and tap Trust. Drag the `.ipa` into Sideloadly and sign in with a free Apple ID.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode**. Then open **Settings → General → VPN & Device Management** and trust that Apple ID.
5. A free Apple ID install lasts about **7 days**. Sideload the same file again. Do not delete Slide first, or the saved days are erased.

## Français

Slide est un suivi de ski et de freestyle pour iPhone (iOS 17+). Sans compte et sans serveur. Les journées restent dans le téléphone. Quatorze langues, dont le français et l’anglais.

Installation sans Xcode : **Sideloadly** sur Windows et un **Apple ID gratuit**. Les fichiers sont sur la [version v1.0](https://github.com/samuel10tecu-tech/slide/releases/tag/v1.0).

1. Télécharge [Slide.ipa](https://github.com/samuel10tecu-tech/slide/releases/download/v1.0/Slide.ipa). Si Sideloadly refuse l’extension Live Activity, prends [Slide-no-extension.ipa](https://github.com/samuel10tecu-tech/slide/releases/download/v1.0/Slide-no-extension.ipa). Tu perds seulement la vitesse sur la Dynamic Island.
2. Sur Windows, installe **iTunes** et **iCloud** depuis le site d’Apple, pas depuis le Microsoft Store. Installe **Sideloadly** depuis https://sideloadly.io/.
3. Branche l’iPhone, déverrouille-le et touche Faire confiance. Glisse le `.ipa` dans Sideloadly et connecte-toi avec un Apple ID gratuit.
4. Sur l’iPhone, active **Réglages → Confidentialité et sécurité → Mode développeur**. Puis ouvre **Réglages → Général → VPN et gestion de l’appareil** et fais confiance à cet Apple ID.
5. Une installation avec un Apple ID gratuit dure environ **7 jours**. Recharge le même fichier. Ne supprime pas Slide avant, sinon les journées disparaissent.

---

# Guide

Offline ski and freestyle tracker for iPhone (iOS 17+, aimed at iPhone 15 Pro). No account, no server. Install it from a Mac with Xcode and a **free Apple ID**.

The interface is in **14 languages**: English, Français, Deutsch, Italiano, Español, Português, Nederlands, Svenska, Norsk, Polski, Čeština, 日本語, 한국어 and 简体中文. Profile → Language: System (follows the phone) or any of those. iOS permission dialogs stay in the phone’s language. Everything inside Slide, including the freestyle library, follows the switch.

The install path below does **not** use Xcode. It uses Sideloadly on Windows. A later section still explains the Mac + Xcode path.

## Install with Sideloadly on Windows

Use this when the Mac’s Apple ID is blocked by Screen Time and Xcode cannot be installed.

### On the Windows PC

1. Install **iTunes** and **iCloud** from Apple’s website, not from the Microsoft Store. The Microsoft Store versions do not talk to Sideloadly.
   - iTunes: https://www.apple.com/itunes/
   - iCloud: https://www.apple.com/icloud/ (download the Windows installer from the page, or the direct Apple support download if the site offers “iCloud for Windows”)
2. Install **Sideloadly** from https://sideloadly.io/ (the Windows installer).
3. Download `Slide.ipa`. If Sideloadly refuses the Live Activity extension, use `Slide-no-extension.ipa` instead. You lose the speed on the Dynamic Island; the rest of the app is the same.
4. Plug the iPhone into the PC with a cable. Unlock the phone and tap **Trust** if it asks.
5. Open Sideloadly. Drag the `.ipa` onto the window.
6. Pick the iPhone in the device list.
7. Enter the **free Apple ID** (an email Apple accepts). An adult’s free Apple ID is fine if a child’s ID is too young. Sideloadly may send a verification code.
8. Start the install and leave the cable connected until it finishes. The first time can take several minutes.

Sideloadly re-signs the app with that Apple ID. The `.ipa` in this project is only ad-hoc signed (or unsigned). It is not tied to a paid developer account.

### On the iPhone

1. **Settings → Privacy & Security → Developer Mode**. Turn it on. The iPhone restarts. After restart, confirm **Turn On**. If the row is missing, finish the Sideloadly install once and look again.
2. **Settings → General → VPN & Device Management**.
3. Under **Developer App**, tap the Apple ID that Sideloadly used, then **Trust**.
4. Open **Slide** from the home screen.
5. On the first **Start**, allow location. Then set **Settings → Privacy & Security → Location Services → Slide → Always**, so tracking continues with the screen locked.
6. Allow Motion if iOS asks (altitude and estimated airtime).

### Every 7 days

A free Apple ID install expires after about **7 days**. The icon stays, but the app will not open.

Sideload the **same** `.ipa` again with Sideloadly. **Do not delete Slide first.** Deleting it erases the saved days. Re-sideloading with the same Apple ID and the same bundle id (`ch.geneve.slide.ski`) keeps the data.

## Installer avec Sideloadly sur Windows

À utiliser quand l’Apple ID du Mac est limité par Temps d’écran et que Xcode ne s’installe pas.

### Sur le PC Windows

1. Installe **iTunes** et **iCloud** depuis le site d’Apple, pas depuis le Microsoft Store. Les versions du Store ne parlent pas à Sideloadly.
   - iTunes : https://www.apple.com/itunes/
   - iCloud : https://www.apple.com/icloud/ (l’installateur Windows proposé sur la page, ou le téléchargement « iCloud pour Windows » d’Apple)
2. Installe **Sideloadly** depuis https://sideloadly.io/ (l’installateur Windows).
3. Télécharge `Slide.ipa`. Si Sideloadly refuse l’extension Live Activity, prends `Slide-no-extension.ipa`. Tu perds la vitesse sur la Dynamic Island ; le reste de l’app est le même.
4. Branche l’iPhone au PC avec un câble. Déverrouille-le et touche **Faire confiance** s’il le demande.
5. Ouvre Sideloadly. Glisse le fichier `.ipa` dans la fenêtre.
6. Choisis l’iPhone dans la liste.
7. Entre l’**Apple ID gratuit** (une adresse qu’Apple accepte). L’Apple ID gratuit d’un adulte convient si celui d’un enfant est trop jeune. Sideloadly peut envoyer un code de vérification.
8. Lance l’installation et laisse le câble branché jusqu’à la fin. La première fois peut prendre plusieurs minutes.

Sideloadly re-signe l’app avec cet Apple ID. Le `.ipa` du projet n’est signé qu’en ad hoc (ou pas du tout). Il n’est pas lié à un compte développeur payant.

### Sur l’iPhone

1. **Réglages → Confidentialité et sécurité → Mode développeur**. Active-le. L’iPhone redémarre. Après le redémarrage, confirme **Activer**. Si la ligne n’existe pas, termine une fois l’installation Sideloadly puis regarde encore.
2. **Réglages → Général → VPN et gestion de l’appareil**.
3. Sous **App de développement**, touche l’Apple ID utilisé par Sideloadly, puis **Faire confiance**.
4. Ouvre **Slide** depuis l’écran d’accueil.
5. Au premier **Démarrer**, autorise la position. Ensuite : **Réglages → Confidentialité et sécurité → Service de localisation → Slide → Toujours**, pour que le suivi continue écran verrouillé.
6. Autorise le mouvement si iOS le demande (altitude et airtime estimé).

### Tous les 7 jours

Une installation avec un Apple ID gratuit expire au bout d’environ **7 jours**. L’icône reste, mais l’app ne s’ouvre plus.

Recharge le **même** `.ipa` avec Sideloadly. **Ne supprime pas Slide avant.** La supprimer efface les journées enregistrées. Recharger avec le même Apple ID et le même identifiant (`ch.geneve.slide.ski`) garde les données.

---

# English

## What you need

- A Mac with a recent macOS
- [Xcode](https://apps.apple.com/app/xcode/id497799835) 16 or newer, free on the Mac App Store
- An iPhone on **iOS 17 or later**
- A cable for the first install
- A **free Apple ID**. The paid developer program is not required.

If you are under 13, or the Apple ID is refused because of age, an adult signs in to Xcode with their own free Apple ID. The app still installs on your iPhone.

## Install Slide

### 1. Open the project

1. Copy this folder to the Mac.
2. Double-click `Slide.xcodeproj`.
3. If Xcode asks to install extra components, accept.

### 2. Sign in

1. **Xcode → Settings… → Accounts**.
2. **+** → **Apple ID**, and sign in with the free account.
3. You should see a team like **Your Name (Personal Team)**.

### 3. Pick the iPhone and the team

1. Plug in the iPhone. If it asks to trust the computer, tap **Trust** and enter the passcode.
2. At the top of Xcode, next to the Play button, choose **your iPhone**, not a simulator.
3. In the left column, click the blue **Slide** project, then the **Slide** target.
4. **Signing & Capabilities**.
5. Check **Automatically manage signing**.
6. **Team**: your Personal Team.
7. Bundle identifier: `ch.geneve.slide.ski`. If it is already taken, change it to something unique such as `ch.geneve.slide.ski.yourname` (no spaces, no capitals). Change the **SlideActivity** target’s bundle id the same way, keeping it as `<app id>.liveactivity`, and give that target the same team.

There is no paid capability (no iCloud, no push, no HealthKit). Background location is already in `Info.plist`. If Xcode warns about it: **Signing & Capabilities → + Capability → Background Modes → Location updates**. A free account can do that.

### 4. Turn on Developer Mode

1. On the iPhone: **Settings → Privacy & Security**.
2. At the bottom: **Developer Mode**.
3. Turn it on. The iPhone restarts.
4. After restart, confirm **Turn On**.

If the row is missing, run the app from Xcode once (step 5). iOS often adds the menu after that.

### 5. Run

1. Scheme **Slide**, destination your iPhone.
2. Press Play (`Cmd + R`). The first build can take several minutes.
3. If the iPhone says the developer is not trusted, do the next step.

### 6. Trust the developer

1. **Settings → General → VPN & Device Management**.
2. Under **Developer App**, tap the profile with the Apple ID email.
3. **Trust**, then confirm.

Open Slide from the home screen. The icon is a light-green line on a dark background.

### 7. Location “Always”

1. The first **Start** asks for location. Allow **While Using**.
2. When iOS offers **Always**, accept it.
3. If you don’t see Always: **Settings → Privacy & Security → Location Services → Slide → Always**.

Always is only for a session, so tracking continues in a pocket with the screen locked. Slide **stops GPS** when you press Stop. A blue pill means iOS is showing that GPS is on.

Also allow **Motion & Fitness** if asked: barometer (altitude) and accelerometer (estimated airtime).

### 8. Every 7 days

A **free** Apple ID certificate lasts about **7 days**. The app will not open until you run it again from Xcode (plug in the phone, press Play).

Do **not** delete the app to “fix” it. Your days live on the phone. A new Run with the **same** bundle id keeps them. Changing the bundle id makes a different app.

## Sharing the app vs sharing a day

A free Apple ID **cannot** send the app itself (no TestFlight). TestFlight and the App Store need the **paid Apple Developer program**, in an **adult’s** name if you are under 18.

You can still send a day with AirDrop or Messages:

- **GPX** track
- a **stats image**
- a **.slide** file (full session). Older **.glisse** files still import.

## What the app does

- **Tracking** — speed gauge, max speed, distance, vertical, altitude, time, run count. Live map (hybrid) with the track coloured by speed, follow mode, speed and altitude on the map. Start, pause, stop. The map tiles can be blank offline; the numbers still work. When a fix arrives, Slide asks MapKit to cache the area around you. That only helps if the phone has had a network once, and it is not a full offline map of the resort.
- **Dynamic Island / Lock Screen** — a Live Activity with current speed while you track. This uses ActivityKit only. It does **not** need a paid entitlement. If Live Activities are off in iOS settings, Slide just skips it.
- **No home-screen widget.** A widget that reads your saved days would need App Groups, and a free Personal Team cannot use App Groups.
- **History** — season totals (1 September–31 August), records, speed and altitude charts, bars per run, replay of the track on the map, tap the line to read the speed at that point.
- **Freestyle** — offline tips in all 14 languages, from park rules up through grabs, rails, butters, 540, and supervised inversions (backflip, frontflip, cork 360). Those are marked **Coach required**. The order is trampoline with a spotter, then water ramp or airbag, then snow only with a coach. The checklist and notes stay on the phone.
- **Profile** — name, resort, units (km/h by default), language, screen-on while tracking, sample day.

## Tests

In Xcode: **Product → Test** (`Cmd + U`) with an iPhone simulator. The tests replay fake tracks (bad accuracy, speed spikes, a descent, a lift, two runs, airtime, GPX). They do not use GPS.

## Limits

- Map tiles need a cache. Stats, replay markers you already recorded, and the shared image do not.
- Airtime is an estimate.
- A full day of precise GPS uses the battery. Cold makes it worse. Start full, inside pocket, Low Power Mode off.
- Inverted tricks in the library are not an invitation to try them alone on a resort jump.

---

# Français

Application de ski et de freestyle pour iPhone (iOS 17+, visée iPhone 15 Pro). **Sans compte et sans serveur.** Elle s’installe depuis un Mac avec Xcode et un **Apple ID gratuit**.

L’interface est en **14 langues** : English, Français, Deutsch, Italiano, Español, Português, Nederlands, Svenska, Norsk, Polski, Čeština, 日本語, 한국어 et 简体中文. Profil → Langue : Système (celle du téléphone), ou l’une de ces langues. Les demandes iOS (position, mouvement) restent dans la langue du téléphone. Tout l’intérieur de Slide, bibliothèque freestyle comprise, suit le réglage.

## Ce qu’il te faut

- Un Mac avec un macOS récent
- [Xcode](https://apps.apple.com/app/xcode/id497799835) 16 ou plus récent, gratuit sur le Mac App Store
- Un iPhone sous **iOS 17 ou plus récent**
- Un câble pour la première installation
- Un **Apple ID gratuit**. Le programme développeur payant n’est pas nécessaire.

Si tu as moins de 13 ans, ou si l’Apple ID est refusé à cause de l’âge, un adulte se connecte dans Xcode avec son propre Apple ID gratuit. L’app s’installe quand même sur ton iPhone.

## Installer Slide

### 1. Ouvrir le projet

1. Copie ce dossier sur le Mac.
2. Double-clique sur `Slide.xcodeproj`.
3. Si Xcode propose d’installer des composants, accepte.

### 2. Connecter l’Apple ID

1. **Xcode → Settings… → Accounts** (Réglages → Comptes).
2. **+** puis **Apple ID**, et connecte-toi avec le compte gratuit.
3. Tu dois voir une équipe du type **« Ton Nom (Personal Team) »**.

### 3. Choisir l’iPhone et l’équipe

1. Branche l’iPhone. S’il demande de faire confiance à l’ordinateur, touche **Faire confiance** et entre le code.
2. En haut de Xcode, à côté du bouton Play, choisis **ton iPhone**, pas un simulateur.
3. Dans la colonne de gauche, clique sur le projet bleu **Slide**, puis sur la cible **Slide**.
4. Onglet **Signing & Capabilities**.
5. Coche **Automatically manage signing**.
6. **Team** : ton Personal Team.
7. L’identifiant est `ch.geneve.slide.ski`. S’il est déjà pris, change-le en quelque chose d’unique, par exemple `ch.geneve.slide.ski.tonprenom` (pas d’espace, pas de majuscule). Fais la même chose pour la cible **SlideActivity** : même équipe, et l’identifiant doit rester `<identifiant de l’app>.liveactivity`.

Aucune capacité payante (pas d’iCloud, pas de notifications push, pas de HealthKit). Le suivi en arrière-plan est déjà dans `Info.plist`. Si Xcode le signale : **Signing & Capabilities → + Capability → Background Modes → Location updates**. Un compte gratuit suffit.

### 4. Activer le Mode développeur

1. Sur l’iPhone : **Réglages → Confidentialité et sécurité**.
2. Tout en bas : **Mode développeur**.
3. Active-le. L’iPhone redémarre.
4. Après le redémarrage, confirme **Activer**.

Si la ligne n’existe pas, lance une fois l’app depuis Xcode (étape 5). iOS ajoute souvent ce menu juste après.

### 5. Lancer

1. Schéma **Slide**, destination ton iPhone.
2. Bouton Play (`Cmd + R`). La première compilation peut prendre plusieurs minutes.
3. Si l’iPhone dit que le développeur n’est pas approuvé, passe à l’étape suivante.

### 6. Faire confiance au développeur

1. **Réglages → Général → VPN et gestion de l’appareil**.
2. Sous **App de développement**, touche le profil avec l’adresse Apple.
3. **Faire confiance**, puis confirme.

Ouvre Slide depuis l’écran d’accueil. L’icône est un trait vert clair sur fond sombre.

### 7. Position « Toujours »

1. Au premier **Démarrer**, accepte **Lorsque l’app est active**.
2. Quand iOS propose **Toujours**, accepte.
3. Si tu ne vois pas Toujours : **Réglages → Confidentialité et sécurité → Service de localisation → Slide → Toujours**.

« Toujours » sert pendant une sortie, pour continuer dans la poche écran verrouillé. Slide **coupe le GPS** quand tu appuies sur Stop. Une pastille bleue veut dire qu’iOS montre que le GPS tourne.

Autorise aussi **Mouvement et forme** si on te le demande : baromètre (altitude) et accéléromètre (airtime estimé).

### 8. Tous les 7 jours

Avec un Apple ID **gratuit**, le certificat dure environ **7 jours**. L’app ne s’ouvre plus tant que tu ne la relances pas depuis Xcode (branche le téléphone, appuie sur Play).

**Ne supprime pas l’app** pour la « réparer ». Tes journées sont dans le téléphone. Un nouveau Run avec le **même** identifiant les garde. Changer l’identifiant crée une autre app.

## Partager l’app, ou partager une journée

Un Apple ID gratuit **ne peut pas** envoyer l’application elle-même (pas de TestFlight). TestFlight et l’App Store demandent le **programme Apple Developer payant**, **au nom d’un adulte** si tu es mineur.

Tu peux quand même envoyer une journée par AirDrop ou Messages :

- un **GPX**
- une **image** de stats
- un fichier **.slide** (la sortie complète). Les anciens fichiers **.glisse** s’importent encore.

## Ce que fait l’app

- **Suivi** — jauge de vitesse, max, distance, dénivelé, altitude, durée, nombre de descentes. Carte live (hybride) avec la trace colorée par la vitesse, mode suivi, vitesse et altitude sur la carte. Démarrer, pause, stop. Les tuiles peuvent rester vides hors ligne ; les chiffres marchent. Dès qu’un point GPS arrive, Slide demande à MapKit de mettre en cache les alentours. Ça n’aide que si le téléphone a déjà eu du réseau, et ce n’est pas une carte hors ligne de toute la station.
- **Dynamic Island / écran verrouillé** — une Live Activity avec la vitesse pendant le suivi. ActivityKit seulement, **sans** capacité payante. Si les activités en direct sont désactivées dans les réglages iOS, Slide n’en lance pas.
- **Pas de widget d’écran d’accueil.** Un widget qui lirait tes journées aurait besoin d’App Groups, et une équipe personnelle gratuite ne peut pas s’en servir.
- **Historique** — totaux de saison (1er septembre–31 août), records, graphiques de vitesse et d’altitude, barres par descente, replay de la trace sur la carte, toucher la ligne pour la vitesse à cet endroit.
- **Freestyle** — textes hors ligne dans les 14 langues, des règles du park jusqu’aux grabs, rails, butters, 540, et aux inversés supervisés (backflip, frontflip, cork 360). Ils sont marqués **Avec un coach**. L’ordre : trampoline avec un pareur, puis tremplin d’eau ou airbag, puis neige seulement avec un coach. La checklist et les notes restent dans le téléphone.
- **Profil** — prénom, station, unités (km/h par défaut), langue, écran allumé pendant le suivi, journée d’exemple.

## Tests

Dans Xcode : **Product → Test** (`Cmd + U`), avec un simulateur iPhone. Les tests rejouent des traces fictives (mauvaise précision, pics de vitesse, une descente, une remontée, deux runs, airtime, GPX). Ils n’utilisent pas le GPS.

Sans iPhone, si Swift est installé :

```bash
swiftc -parse-as-library -o /tmp/slide-tests \
  Slide/Logic/*.swift \
  SlideTests/LogicChecks.swift \
  tooling/linux-main.swift
/tmp/slide-tests
```

Ça doit afficher `OK — logique Slide`.

## Limites

- Les tuiles de carte ont besoin d’un cache. Les stats, le replay de points déjà enregistrés et l’image partagée n’en ont pas besoin.
- L’airtime est une estimation.
- Une journée de GPS précis use la batterie. Le froid encore plus. Pars chargé, poche intérieure, mode économie d’énergie désactivé.
- Les figures inversées de la bibliothèque ne sont pas une invitation à les tenter seul sur un saut de station.
