# Slide

Offline ski and freestyle tracker for iPhone (iOS 17+, aimed at iPhone 15 Pro). No account, no server. Install it from a Mac with Xcode and a **free Apple ID**.

The interface is **English and French**. Profile → Language: System (follows the phone), English, or Français. iOS permission dialogs stay in the phone’s language. Everything inside Slide follows the switch.

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
- **Freestyle** — offline tips in both languages, from park rules up through grabs, rails, butters, 540, and supervised inversions (backflip, frontflip, cork 360). Those are marked **Coach required**. The order is trampoline with a spotter, then water ramp or airbag, then snow only with a coach. The checklist and notes stay on the phone.
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

L’interface est en **anglais et en français**. Profil → Langue : Système (celle du téléphone), English, ou Français. Les demandes iOS (position, mouvement) restent dans la langue du téléphone. Tout l’intérieur de Slide suit le réglage.

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
- **Freestyle** — textes hors ligne dans les deux langues, des règles du park jusqu’aux grabs, rails, butters, 540, et aux inversés supervisés (backflip, frontflip, cork 360). Ils sont marqués **Avec un coach**. L’ordre : trampoline avec un pareur, puis tremplin d’eau ou airbag, puis neige seulement avec un coach. La checklist et les notes restent dans le téléphone.
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
