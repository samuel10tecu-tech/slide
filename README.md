# Glisse

Application iPhone pour suivre une journée de ski freestyle, **sans compte et sans réseau**. Elle est pensée pour un iPhone sous iOS 17 (visée : iPhone 15 Pro) et s'installe depuis un Mac avec Xcode et un **Apple ID gratuit**.

Glisse mesure la vitesse, la distance, le dénivelé et la durée, sépare tout seul les descentes, les remontées et les pauses, garde l'historique sur le téléphone, propose une bibliothèque de tricks en français, et permet d'envoyer une sortie à un ami par AirDrop ou Messages.

Rien n'est envoyé sur un serveur. Il n'y a pas de publicité et pas d'inscription.

## Ce qu'il te faut

- Un Mac avec macOS récent
- [Xcode](https://apps.apple.com/app/xcode/id497799835) 16 ou plus récent, gratuit sur le Mac App Store (le premier téléchargement est lourd)
- Un iPhone sous **iOS 17 ou plus récent**
- Un câble pour brancher l'iPhone au Mac (le plus simple pour la première fois)
- Un **Apple ID gratuit**. Pas besoin du programme développeur payant.

Si tu as moins de 13 ans, ou si l'Apple ID refuse à cause de l'âge, un adulte se connecte dans Xcode avec **son** Apple ID gratuit. L'app s'installe quand même sur ton iPhone.

## Installer Glisse sur l'iPhone

### 1. Ouvrir le projet

1. Copie ce dossier sur le Mac.
2. Double-clique sur `Glisse.xcodeproj`. Xcode s'ouvre.
3. Si Xcode propose d'installer des composants supplémentaires, accepte.

### 2. Connecter l'Apple ID

1. Dans Xcode : **Xcode → Settings… → Accounts** (Réglages → Comptes).
2. Clique sur **+** puis **Apple ID**, et connecte-toi avec l'identifiant gratuit.
3. Tu dois voir une équipe du type **« Ton Nom (Personal Team) »**.

### 3. Choisir l'iPhone et l'équipe de signature

1. Branche l'iPhone. S'il demande « Faire confiance à cet ordinateur ? », touche **Faire confiance** et entre le code du téléphone.
2. En haut de Xcode, à côté du bouton Play, choisis **ton iPhone**, pas un simulateur.
3. Dans la colonne de gauche, clique sur le projet **Glisse** (l'icône bleue), puis sur la cible **Glisse**.
4. Onglet **Signing & Capabilities**.
5. Coche **Automatically manage signing**.
6. Dans **Team**, choisis le Personal Team.
7. Le **Bundle Identifier** est `ch.geneve.glisse.ski`. S'il est déjà pris dans le monde, Xcode affiche une erreur rouge. Change-le en quelque chose d'unique, par exemple `ch.geneve.glisse.ski.tonprenom`. Ne mets pas d'espace ni de majuscule.

Il n'y a **aucune capacité payante** à ajouter (pas d'iCloud, pas de notifications push, pas de HealthKit). Le suivi en arrière-plan est déjà déclaré dans `Info.plist` (`UIBackgroundModes` → `location`). Si Xcode affiche un bandeau sur le mode arrière-plan, ouvre **Signing & Capabilities → + Capability → Background Modes** et coche **Location updates**. Ça ne demande pas de compte payant.

### 4. Activer le Mode développeur sur l'iPhone

À partir d'iOS 16, un iPhone n'accepte une app installée par Xcode qu'après avoir activé le Mode développeur.

1. Sur l'iPhone : **Réglages → Confidentialité et sécurité**.
2. Tout en bas : **Mode développeur**.
3. Active-le. L'iPhone redémarre.
4. Après le redémarrage, confirme **Activer**.

Si la ligne n'existe pas encore, lance une première fois l'app depuis Xcode (étape 6) : iOS ajoute souvent ce menu juste après.

### 5. Lancer l'installation

1. Dans Xcode, le schéma **Glisse** et ton iPhone sont sélectionnés.
2. Appuie sur le bouton **Play** (ou `Cmd + R`).
3. La première compilation peut prendre plusieurs minutes.
4. Si une erreur parle de « Untrusted Developer » ou si l'app ne s'ouvre pas, passe à l'étape suivante. Le message exact sur l'iPhone est souvent : l'entreprise de développement n'est pas approuvée.

### 6. Faire confiance au développeur sur l'iPhone

1. **Réglages → Général → VPN et gestion de l'appareil** (parfois **Gestion des profils et de l'appareil**).
2. Sous **App de développement**, touche le profil à ton adresse Apple.
3. Touche **Faire confiance à « … »**, puis confirme.

Relance Glisse depuis l'écran d'accueil. L'icône est un trait vert clair sur fond sombre.

### 7. Autoriser la position « Toujours »

Au premier **Démarrer**, iOS demande la position.

1. Accepte **Lorsque l'app est active**.
2. iOS propose ensuite (tout de suite ou un peu plus tard) l'accès **Toujours**. Accepte-le.
3. Si tu ne vois pas « Toujours » : **Réglages → Confidentialité et sécurité → Service de localisation → Glisse → Toujours**.

« Toujours » sert uniquement pendant une sortie, pour continuer quand l'écran est verrouillé et le téléphone dans la poche. Glisse **coupe le GPS** quand tu appuies sur Stop. Une pastille ou une barre bleue peut s'afficher : c'est iOS qui indique que le GPS tourne. C'est normal.

Autorise aussi le **mouvement et la forme** si iOS le demande : c'est le baromètre (altitude) et l'accéléromètre (estimation du temps de vol).

### 8. Tous les 7 jours

Avec un Apple ID **gratuit**, le certificat expire au bout d'environ **7 jours**. L'app ne s'ouvre plus tant que tu ne l'as pas relancée depuis Xcode (branche le téléphone, appuie sur Play).

- **Ne supprime pas l'app** pour la « réparer » : tes journées sont dans le téléphone. Un nouveau Run depuis Xcode, avec le **même** Bundle Identifier, les garde.
- Si tu changes le Bundle Identifier, iOS considère que c'est une autre app et l'ancienne mémoire ne suit pas.

## Partager l'app avec des amis

Un Apple ID gratuit **ne peut pas** envoyer l'application elle-même (pas de TestFlight, pas de lien d'installation).

**TestFlight** et l'App Store demandent le **programme Apple Developer payant** (compte annuel), **au nom d'un adulte** si tu es mineur. Ce dépôt ne le configure pas.

Ce que tu peux partager sans ça, depuis une journée enregistrée :

- un fichier **GPX** (la trace)
- une **image** avec les stats
- un fichier **.glisse** (la sortie complète : descentes, vitesses, sauts estimés)

Boutons dans le détail d'une journée, ou juste après Stop. AirDrop et Messages passent par la feuille de partage iOS. L'ami importe le fichier dans Glisse : Historique → icône de téléchargement, ou « Ouvrir dans Glisse ».

## Utiliser l'app

Quatre onglets :

- **Suivi** — gros chiffre de vitesse (lisible avec des gants), vitesse max, distance, dénivelé, altitude, durée, nombre de descentes. Démarrer, pause, stop.
- **Historique** — totaux de la saison (1er septembre → 31 août), records (vitesse, plus longue descente, plus gros dénivelé d'une journée), carte colorée par la vitesse, détail de chaque descente.
- **Freestyle** — conseils hors ligne (étiquette du park, sauts, ollie, rotations, grabs, rails, butters, switch, réception) et une checklist personnelle avec notes.
- **Profil** — prénom, station, unités (km/h par défaut, ou mph / miles / pieds), écran allumé, journée d'exemple, effacement.

La journée d'exemple (Profil) montre l'historique avant la première vraie sortie. Elle est marquée « Exemple » et se supprime.

## Tests

Dans Xcode : **Product → Test** (`Cmd + U`), avec un simulateur iPhone (iPhone 15 Pro par exemple).

Les tests ne parlent pas au GPS. Ils rejouent des traces fictives : points trop imprécis, pics de vitesse impossibles, bruit quand on est arrêté, une descente, une remontée, deux descentes, l'estimation d'airtime, le GPX et le fichier `.glisse`.

## Limites

- **100 % hors ligne pour les chiffres.** La carte MapKit peut rester grise tant que le fond de carte n'a pas été mis en cache une fois avec du réseau. Les stats, la liste des descentes et l'image partagée n'en ont pas besoin : le tracé de l'image est dessiné dans l'app.
- Le **temps de vol** est une estimation de l'accéléromètre. Utile pour comparer tes sauts, pas une mesure exacte. Il n'est compté que si tu vas déjà vite, pour ignorer les gestes à l'arrêt.
- La détection des descentes utilise la tendance d'altitude et la vitesse, avec un peu de délai (quelques secondes) pour ne pas couper un run à chaque plat. Un tout petit bout de piste peut ne pas être compté. Un pic GPS aberrant est jeté.
- L'altitude préfère le **baromètre** de l'iPhone, recalé de temps en temps sur le GPS. Le simulateur n'a en général pas de baromètre : l'app retombe sur l'altitude GPS.
- Le GPS en précision maximale, toute une journée, **use la batterie**. Le froid encore plus. Poche intérieure, batterie pleine, mode économie d'énergie désactivé (il peut couper le GPS).
- Pas de compte, pas de sync entre téléphones, pas de classement en ligne. Pour comparer, on s'envoie la trace.
- L'app n'apprend pas les figures inversées (cork, backflip). Ça se fait avec un coach, pas tout seul au park.
- Secours en Suisse : **144** (ambulance), **1414** (REGA). En France : **112**.

## Lancer les tests de logique sans iPhone

Les fichiers dans `Glisse/Logic` ne dépendent pas d'iOS. Sur un Mac avec Swift, ou là où le compilateur Swift est installé :

```bash
swiftc -parse-as-library -o /tmp/glisse-tests \
  Glisse/Logic/*.swift \
  GlisseTests/LogicChecks.swift \
  tooling/linux-main.swift
/tmp/glisse-tests
```

Ça doit afficher `OK — logique Glisse`. Le fichier `tooling/linux-main.swift` n'est pas dans l'app iPhone.
