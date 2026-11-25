import Foundation

struct Trick: Identifiable, Hashable {
    enum Level: String, CaseIterable, Identifiable {
        case debutant = "Débutant"
        case intermediaire = "Intermédiaire"
        case avance = "Avancé"
        case expert = "Expert"
        var id: String { rawValue }
    }

    enum Category: String, CaseIterable, Identifiable {
        case securite = "Sécurité"
        case sauts = "Sauts"
        case pop = "Pop"
        case rotations = "Rotations"
        case grabs = "Grabs"
        case rails = "Rails & boxes"
        case butters = "Butters"
        case switchRiding = "Switch"
        case reception = "Réception"
        var id: String { rawValue }
    }

    let id: String
    let name: String
    let level: Level
    let category: Category
    let summary: String
    let steps: [String]
    let safety: String
    let tips: [String]
}

enum TrickLibrary {
    static let tricks: [Trick] = [
        Trick(
            id: "park-rules",
            name: "Le park, les règles",
            level: .debutant,
            category: .securite,
            summary: "Le snowpark n'est pas une piste normale. Tout le monde descend dans le même sens, et personne ne s'arrête sur une réception.",
            steps: [
                "Regarde le plan du jour au départ. Les modules ont une taille : S, M, L, XL. Commence par S.",
                "Avant de partir, regarde en haut ET en bas. Un coup d'œil, puis tu t'engages.",
                "Ne traverse pas un kick ou un rail. Tu suis la ligne, tu sors, tu dégages sur le côté.",
                "Si tu tombes, sors de la ligne tout de suite, même si tu as mal. La personne derrière ne te voit pas assez tôt.",
                "Un seul rider à la fois sur un module. Tu attends que la réception soit libre."
            ],
            safety: "En Suisse, les secours : 144 (ambulance) et 1414 (REGA, hélico). En France voisine : 112. Mets ces numéros dans ton téléphone avant de monter.",
            tips: [
                "Le casque est fermé avant le premier télésiège, pas « pour le park seulement ».",
                "Si la neige est dure ou que tu es fatigué, le park peut attendre. La plupart des grosses chutes arrivent en fin de journée."
            ]
        ),
        Trick(
            id: "protections",
            name: "Casque et dorsale",
            level: .debutant,
            category: .securite,
            summary: "Un casque de ski bien réglé, une dorsale, et des gants entiers. Ce n'est pas négociable pour sauter ou slider.",
            steps: [
                "Le casque ne bouge pas quand tu secoues la tête. La sangle est fermée.",
                "La dorsale couvre le milieu du dos, pas seulement les épaules.",
                "Des genoux et des fesses protégés aident le jour où tu apprends les butters et le switch.",
                "Resserre les chaussures. Un jeu dans la coque, et la réception part de travers."
            ],
            safety: "Un bonnet sous le casque ne remplace pas le casque. Les bosses de réception sont souvent dures l'après-midi.",
            tips: [
                "Si le casque a pris un gros choc, on le change. La mousse ne se voit pas, mais elle ne protège plus.",
                "Des gants avec une paume renforcée évitent les mains ouvertes sur un rail."
            ]
        ),
        Trick(
            id: "fall-better",
            name: "Tomber sans se casser",
            level: .debutant,
            category: .securite,
            summary: "Tu vas tomber. Le but est de glisser, pas de planter les mains.",
            steps: [
                "Rentre les bras. Les pouces le long des mains, pas écartés.",
                "Tombe sur le côté, hanche et cuisse, et laisse-toi glisser.",
                "Le menton se rentre vers la poitrine pour que l'arrière du casque touche avant la nuque.",
                "Ne te relève pas tant que tu es sur la ligne d'un saut ou d'un rail."
            ],
            safety: "Une main plantée pour « se rattraper » casse un poignet ou un pouce. Tu acceptes de glisser.",
            tips: [
                "Entraîne-toi à tomber sur une pente douce, à petite vitesse, avant le park.",
                "Si tu as un doute sur une douleur à la tête, au cou ou au dos : tu t'arrêtes, tu appelles. Pas de « encore un run »."
            ]
        ),
        Trick(
            id: "read-jump",
            name: "Lire un saut",
            level: .debutant,
            category: .sauts,
            summary: "Le saut se gagne avant le kick. Tu choisis la vitesse, tu vois la réception, tu décides.",
            steps: [
                "Arrête-toi sur le côté, jamais sur la trajectoire, et regarde le kick puis la réception.",
                "Repère où la piste reprend. Si tu ne vois pas le bas, tu ne pars pas.",
                "Regarde deux riders passer pour comprendre la vitesse : trop court, ou trop long.",
                "Compte un point de départ. Trop haut = trop vite. Trop bas = tu poses sur le plat.",
                "Le premier passage se fait droit, sans grab et sans rotation."
            ],
            safety: "On ne s'arrête jamais sur le plat juste après un kick, ni sur la réception. Les autres arrivent vite.",
            tips: [
                "Un saut S bien pris vaut mieux qu'un M raté.",
                "Si le vent de face est fort ou que la lumière est plate, la réception se voit mal. Attends."
            ]
        ),
        Trick(
            id: "straight-air",
            name: "Saut droit",
            level: .debutant,
            category: .sauts,
            summary: "Le saut droit, c'est la base de tout le reste : pop, corps calme, regard loin.",
            steps: [
                "Arrive en position athlétique : chevilles, genoux et hanches un peu fléchis, mains devant.",
                "Regarde la fin de la réception, pas tes spatules.",
                "Sur la lèvre, tu pousses vers le bas (le pop) et tu laisses les skis monter avec toi. Tu ne jettes pas les épaules en arrière.",
                "En l'air, genoux souples, skis parallèles, poids au milieu.",
                "Tu touches en premier avec les deux skis, puis tu plies pour absorber."
            ],
            safety: "Pas de pop violent sur un kick que tu ne connais pas. D'abord tu le roules presque, ensuite tu ajoutes un peu d'air.",
            tips: [
                "Si tu pars en arrière, c'est souvent le regard et les hanches qui sont restés sur le kick. Regarde loin devant.",
                "Filme-toi de côté. Tu verras tout de suite si tu es cassé à la taille."
            ]
        ),
        Trick(
            id: "landing",
            name: "Réception",
            level: .debutant,
            category: .reception,
            summary: "Une bonne réception est molle dans les jambes et solide dans le regard. Le ski touche, le corps suit.",
            steps: [
                "En l'air, prépare les jambes : ni tendues, ni collées aux fesses.",
                "Cherche la pente avec les skis. Ils se posent dans le sens de la réception, pas à plat sur le plat.",
                "Au contact, plie chevilles-genoux-hanches dans cet ordre, comme un ressort.",
                "Les mains restent basses et devant. Elles ne partent pas au ciel.",
                "Une fois stable, sors de la ligne."
            ],
            safety: "Atterrir tendu, c'est le genou qui encaisse à la place du ressort. Si tu sens que tu es trop long, assume une réception un peu basse plutôt qu'un rattrapage au plat.",
            tips: [
                "Le bruit doit être sourd, pas un claquement. Claquement = jambes raides.",
                "Après trois mauvaises réceptions d'affilée, tu changes de module ou tu arrêtes."
            ]
        ),
        Trick(
            id: "ollie",
            name: "Ollie",
            level: .debutant,
            category: .pop,
            summary: "L'ollie est un pop depuis la queue des skis. Il sert sur un petit hit, une bosse, ou pour décoller une box.",
            steps: [
                "En ligne droite, à vitesse moyenne, fléchis un peu.",
                "Pousse les pieds vers l'avant pour charger la queue, sans t'asseoir.",
                "Déplie d'un coup chevilles et genoux. La spatule monte, la queue suit.",
                "Ramène les genoux pour garder les skis collés aux pieds.",
                "Pose toi à plat, les deux skis ensemble, et absorbe."
            ],
            safety: "Apprends l'ollie sur le plat, loin du monde, avant de l'emmener sur une lèvre.",
            tips: [
                "Si seule la spatule décolle, tu as tiré avec le dos. Le pop vient des jambes.",
                "Un petit ollie propre bat un grand saut déséquilibré."
            ]
        ),
        Trick(
            id: "safety-grab",
            name: "Safety grab",
            level: .debutant,
            category: .grabs,
            summary: "Le safety, c'est attraper le ski juste devant la fixation, entre les deux pieds. Le grab le plus stable pour commencer.",
            steps: [
                "D'abord sur un petit saut droit que tu poses les yeux fermés… non, les yeux ouverts, mais sans y penser.",
                "En l'air, plie les genoux et amène le ski à la main. Tu ne plonges pas la main vers le ski en cassant le dos.",
                "La main avant ou arrière attrape le ski côté intérieur, devant la fixation.",
                "Tu tiens le grab une seconde, tu lâches, tu prépares la réception.",
                "Le regard reste sur la réception pendant tout le grab."
            ],
            safety: "Si tu ne vois plus la piste en attrapant, le grab est trop tôt ou trop bas. Lâche et pose-toi.",
            tips: [
                "Genoux hauts, torse calme. Le grab ne doit pas tourner tes épaules.",
                "Passe le safety des deux côtés avant de changer de grab."
            ]
        ),
        Trick(
            id: "box-5050",
            name: "50-50 sur une box",
            level: .debutant,
            category: .rails,
            summary: "Le 50-50 : les deux skis dans l'axe, au milieu de la box, comme un rail très large et plat.",
            steps: [
                "Choisis une box basse, droite, avec un départ plat.",
                "Regarde la sortie, pas tes skis.",
                "Monte dessus au milieu, skis parallèles, poids égal sur les deux pieds.",
                "Genoux souples, bras bas. Tu ne sautes pas sur la box : tu y roules.",
                "À la fin, tu laisses la box partir et tu absorbes la petite marche."
            ],
            safety: "Première session : casque, et quelqu'un qui regarde. Si tu es de travers, tu sors. Tu n'insistes pas pour « finir ».",
            tips: [
                "Un peu de vitesse, pas une pointe. Trop lent, les skis collent ou dévient.",
                "Le regard qui tombe sur les spatules te fait tomber vers l'avant."
            ]
        ),
        Trick(
            id: "one-eighty",
            name: "180",
            level: .intermediaire,
            category: .rotations,
            summary: "Un demi-tour en l'air. Tu pars en avant, tu poses en switch — ou l'inverse plus tard.",
            steps: [
                "Sache déjà skier un peu en switch, au moins sur une piste bleue douce, pour que la pose ne te fasse pas peur.",
                "Sur un petit kick, pop droit, puis tourne la tête et les épaules dans le sens choisi. Les skis suivent.",
                "Les hanches tournent avec les épaules. Pas seulement les bras.",
                "Tu vises 180, pas 270. Tu bloques le regard vers la réception.",
                "Pose en switch, poids au milieu, et continue tout droit quelques mètres."
            ],
            safety: "Le 180 se fait d'abord sur un jump S, dans les deux sens, avant un module plus grand.",
            tips: [
                "Choisis un sens « facile » (souvent celui où tu regardes par-dessus l'épaule avant) et propre-le avant l'autre.",
                "Si tu sous-tournes, c'est la tête qui est partie trop tard, pas les pieds."
            ]
        ),
        Trick(
            id: "switch-riding",
            name: "Skier en switch",
            level: .intermediaire,
            category: .switchRiding,
            summary: "Switch = à l'envers, l'autre pied devant. Sans ça, les 180 et les slides restent des paris.",
            steps: [
                "Sur le plat, glisse en switch, juste pour sentir quel pied est devant.",
                "Descends une verte entière en switch, virages larges.",
                "Garde les mains basses et le poids un peu plus sur le ski amont, comme en avant… mais tout est miroir.",
                "Fais des traversées, puis des petits virages coupés.",
                "Quand une verte en switch est ennuyeuse, passe à une bleue facile. Pas avant."
            ],
            safety: "Le switch fatigue des muscles que tu n'utilises pas. Arrête-toi avant de croiser quelqu'un n'importe comment.",
            tips: [
                "Cinq minutes à chaque remontée valent mieux qu'une heure le dernier jour des vacances.",
                "Regarde loin. En switch, le regard a tendance à tomber sur la spatule arrière."
            ]
        ),
        Trick(
            id: "nollie",
            name: "Nollie",
            level: .intermediaire,
            category: .pop,
            summary: "Le nollie pop depuis la spatule. C'est le ollie à l'envers, et il prépare le switch.",
            steps: [
                "En ligne droite, avance un peu le bassin pour charger l'avant des skis, sans passer par-dessus.",
                "Pop en dépliant les chevilles. La queue monte en premier.",
                "Ramène les genoux, skis à plat.",
                "Pose toi au milieu du ski.",
                "Alterne ollie et nollie sur le plat jusqu'à ce que les deux aient la même hauteur."
            ],
            safety: "Trop de poids avant, et tu plantes les spatules. Garde les mains devant le bassin, pas au-dessus de la tête.",
            tips: [
                "Le nollie est plus facile à sentir en étant très bas avant le pop.",
                "S'il part de travers, tes épaules ont tourné. Garde-les parallèles aux skis."
            ]
        ),
        Trick(
            id: "mute",
            name: "Mute grab",
            level: .intermediaire,
            category: .grabs,
            summary: "Le mute : la main avant attrape le ski avant, côté extérieur, entre la spatule et la fixation.",
            steps: [
                "Pars d'un saut droit stable, safety déjà propre.",
                "Monte le ski avant vers la main avant. Le genou vient à la poitrine.",
                "Attrape le ski à l'extérieur, pas entre les jambes.",
                "L'autre bras s'écarte un peu pour l'équilibre, sans lancer la rotation.",
                "Lâche tôt, remets les skis parallèles, absorbe."
            ],
            safety: "Un grab qui te fait perdre la réception n'est pas un grab. Tu le raccourcis.",
            tips: [
                "Genou haut, pas dos cassé vers le ski.",
                "Le mute ne doit pas ouvrir ta hanche au point de croiser les skis."
            ]
        ),
        Trick(
            id: "three-sixty",
            name: "360",
            level: .intermediaire,
            category: .rotations,
            summary: "Un tour complet. Tu poses dans le sens de départ. Ça demande un 180 propre des deux côtés.",
            steps: [
                "Petit kick, vitesse de saut droit, pop vers le haut avant de tourner.",
                "La tête part en premier, puis les épaules, puis les hanches. Les skis suivent.",
                "Repère un point dans la réception et retrouve-le à la fin du tour.",
                "Garde les skis groupés. Un ski qui traîne coupe la rotation… ou la finit trop tôt.",
                "Bloque le haut du corps quand tu revois la piste, et pose-toi au milieu."
            ],
            safety: "Pas de 360 sur un M tant que le 360 sur un S est calme, dans un seul sens, dix fois de suite.",
            tips: [
                "Sous-tourner est normal au début. Tu ajoutes la tête, pas un jeté d'épaule violent.",
                "Si tu sur-tournes, tu as pop trop tard et tourné trop tôt. Pop d'abord."
            ]
        ),
        Trick(
            id: "nose-butter",
            name: "Nose butter",
            level: .intermediaire,
            category: .butters,
            summary: "Le nose butter : tu glisses sur la spatule et tu fais pivoter l'arrière. C'est lent, et ça se travaille sur une bosse douce.",
            steps: [
                "Trouve une petite bosse ou un côté de piste mou, presque plat en sortie.",
                "Avance le poids sur les deux spatules, jambes fléchies, dos plutôt droit.",
                "Laisse les queues décrocher et tourner. Tu guides avec les pieds et le regard.",
                "Garde assez de vitesse pour ne pas t'arrêter au milieu.",
                "Ramène les queues dans l'axe avant que la bosse finisse, et redescends le poids au milieu."
            ],
            safety: "Les butters se font loin des autres. Une queue qui balaie accroche les tibias de quelqu'un.",
            tips: [
                "Si tu passes par-dessus, tu étais trop avant ET trop raide. Reste bas.",
                "Vise d'abord un petit angle, pas un 360 butter."
            ]
        ),
        Trick(
            id: "tail-butter",
            name: "Tail butter",
            level: .intermediaire,
            category: .butters,
            summary: "Le tail butter charge la queue. L'avant des skis décolle et tourne. Même logique que le nose, à l'envers.",
            steps: [
                "Sur une bosse douce, recule le poids sur les queues sans t'asseoir.",
                "Fléchis les genoux et laisse les spatules devenir légères.",
                "Tourne les spatules avec les pieds. Le haut du corps reste assez calme.",
                "Le regard va là où tu veux ressortir.",
                "Repose les spatules avant la fin de la bosse et recentre-toi."
            ],
            safety: "S'asseoir sur les queues bloque le ski et te fait tomber en arrière. Reste debout dans les bottes.",
            tips: [
                "Les bras bas t'empêchent de cambrer.",
                "Un tail butter tout petit, tenu longtemps, est plus utile qu'un grand geste raté."
            ]
        ),
        Trick(
            id: "rail-5050",
            name: "50-50 sur un rail",
            level: .intermediaire,
            category: .rails,
            summary: "Même idée que la box, mais le rail est étroit. Tu y vas seulement quand la box droite est devenue facile.",
            steps: [
                "Rail bas, pas trop long, avec un départ que tu peux rouler.",
                "Vitesse régulière. Tu vises le milieu du rail avec le milieu des deux skis.",
                "Regarde la sortie. Les pieds restent à plat, genoux souples.",
                "Si tu commences à partir de côté, tu n'insistes pas : tu sautes dehors.",
                "La sortie s'absorbe comme une petite réception."
            ],
            safety: "Pas de rail rond et haut pour apprendre. Une glissade dessus coupe. Reste sur un tube bas ou une box étroite.",
            tips: [
                "Le bruit doit être continu. Un à-coup = un ski qui mord le bord.",
                "Demande à quelqu'un de te dire si tu montes de travers. Toi, tu ne dois pas regarder tes skis."
            ]
        ),
        Trick(
            id: "absorb",
            name: "Absorber un hit",
            level: .intermediaire,
            category: .reception,
            summary: "Les bosses et les lèvres se prennent avec les jambes, pas avec le dos. Absorber, c'est rester collé à la neige quand tu le veux.",
            steps: [
                "Repère la bosse tôt.",
                "Juste avant, tu es déjà un peu fléchi.",
                "Quand la neige monte, tu plies et tu laisses la bosse venir dans les jambes.",
                "En haut, tu peux pop — ou rester bas si tu ne veux pas décoller.",
                "Dans le creux, tu rallonges les jambes pour garder le contact."
            ],
            safety: "Rester tendu sur une série de bosses fatigue les genoux et finit en travers. Ralentis si tu ne suis plus.",
            tips: [
                "Pense « silencieux ». Moins de bruit sur les bosses = mieux absorbé.",
                "Les mains restent devant toi. Si elles partent en arrière, le pop part avec."
            ]
        ),
        Trick(
            id: "slide",
            name: "Slide sur une box",
            level: .avance,
            category: .rails,
            summary: "Le slide : les skis se mettent en travers de la box, comme un dérapage posé dessus. D'abord presque plat, très lent en rotation.",
            steps: [
                "50-50 propre sur cette même box, dans les deux sens de pied avant.",
                "Monte en 50-50, puis tourne les épaules et les hanches ensemble jusqu'à environ 90°.",
                "Le poids reste au milieu des skis. Tu ne t'assoies pas en aval.",
                "Regarde la sortie par-dessus l'épaule avant.",
                "Ramène les skis dans l'axe avant la fin, ou sors en switch si tu as décidé un 270 — plus tard."
            ],
            safety: "Un slide sur un rail fin vient après des semaines de box. Le bord de ski accroche, et la chute est sèche.",
            tips: [
                "Dérape sur la neige à côté de la box pour sentir 90° avant de monter dessus.",
                "Trop de rotation au départ te met à 180 avant le milieu. Tourne moins, plus tôt."
            ]
        ),
        Trick(
            id: "japan",
            name: "Japan",
            level: .avance,
            category: .grabs,
            summary: "Le japan : tu attrapes la spatule avant, côté extérieur, et le genou s'ouvre un peu. Joli, mais seulement si le mute est stable.",
            steps: [
                "Saut droit, pop haut et calme. Pas de rotation.",
                "La main avant va chercher le bout du ski avant, à l'extérieur.",
                "Le genou avant s'écarte légèrement. Le ski arrière reste proche de l'autre.",
                "Tu ne tires pas le ski dans le dos au point de perdre l'horizon.",
                "Lâche, parallèle, réception au milieu du ski."
            ],
            safety: "Si le japan te met sur la carre arrière, arrête. Reviens au mute jusqu'à ce que l'axe soit neutre.",
            tips: [
                "C'est un grab de style, pas un grab pour « aller plus loin ». La réception compte plus que la photo.",
                "Garde l'autre main basse pour ne pas lancer un 180 sans le vouloir."
            ]
        ),
        Trick(
            id: "five-forty",
            name: "540",
            level: .expert,
            category: .rotations,
            summary: "Un tour et demi. Tu poses en switch. Réservé au moment où tes 360 sont calmes des deux côtés, sur un petit kick, avec quelqu'un qui te regarde.",
            steps: [
                "Pré-requis : 360 propre à gauche et à droite, et switch solide en sortie de saut.",
                "Même pop qu'un 360. La rotation vient de la tête et des hanches, pas d'un jeté tardif.",
                "Tu passes le 360 et tu continues jusqu'à voir la réception en switch.",
                "Tu bloques les épaules, skis groupés, et tu poses switch au milieu.",
                "Tu sors de la ligne avant de fêter ça."
            ],
            safety: "Pas de 540 le premier jour sur un module, pas sans casque, pas si le 360 rate encore une fois sur deux. Si personne d'expérience ne peut te regarder, tu restes au 360. Les figures inversées (cork, backflip) ne s'apprennent pas dans cette app : club, coach, tapis ou airbag.",
            tips: [
                "Sous-tourner un 540, c'est poser de travers en switch. Mieux vaut un 360 assumé.",
                "La vitesse est celle de ton saut droit sur CE kick. Pas un élan de plus « pour la rotation »."
            ]
        ),
        Trick(
            id: "switch-180",
            name: "Switch 180",
            level: .avance,
            category: .switchRiding,
            summary: "Tu pars en switch et tu poses en avant. C'est souvent plus facile que le 180 classique, parce que la réception est dans ton sens fort.",
            steps: [
                "Switch propre sur une bleue, et ollie/nollie déjà en place.",
                "Petit kick. Tu arrives en switch, tu pop, la tête tourne vers ton sens habituel.",
                "Les skis passent 180 et retrouvent l'avant.",
                "Tu poses comme un saut droit normal et tu absorbes.",
                "Fais-le des deux côtés avant de l'emmener sur un plus grand kick."
            ],
            safety: "L'approche en switch est le vrai risque : tu vois moins bien les autres. Regarde deux fois avant de partir.",
            tips: [
                "Si tu rates l'approche, tu ne « tentes quand même ». Tu roules le kick sans pop.",
                "Garde la rotation petite et haute. Un switch 180 plat finit en queue plantée."
            ]
        ),
        Trick(
            id: "coach-wall",
            name: "Ce que Glisse ne t'apprend pas",
            level: .expert,
            category: .securite,
            summary: "Les inversés, les corks, les flips et les doubles ne sont pas expliqués ici. Ils se travaillent avec un coach, dans un club, souvent sur un airbag — pas seuls au snowpark.",
            steps: [
                "Si une figure te fait quitter le sol la tête en bas, il te faut un adulte qui sait, et un plan de progression.",
                "Autour de Genève, les clubs de ski et les snowparks (Crosets, Avoriaz, Les Gets, Chamonix, Verbier…) changent chaque hiver. Le plan du jour au départ fait foi, pas une vidéo.",
                "Une vidéo ralentie n'est pas un cours. Elle ne voit pas ta vitesse ni la neige de cet après-midi.",
                "Quand tu veux progresser vite, un cours collectif freestyle t'avance plus qu'une heure à deviner."
            ],
            safety: "Aucune app ne remplace quelqu'un qui peut dire « non, pas aujourd'hui ». Écoute cette personne.",
            tips: [
                "Filme tes bases (saut droit, 180, 360). Le progrès se voit là, avant les figures de magazine.",
                "La peur est une info. Si tu n'as pas envie, tu ne dois rien à personne."
            ]
        ),
    ]

    static func trick(_ id: String) -> Trick? {
        tricks.first { $0.id == id }
    }
}
