import Foundation

struct Trick: Identifiable, Hashable {
    enum Level: String, CaseIterable, Identifiable {
        case debutant
        case intermediaire
        case avance
        case expert
        var id: String { rawValue }
    }

    enum Category: String, CaseIterable, Identifiable {
        case securite
        case sauts
        case pop
        case rotations
        case grabs
        case rails
        case butters
        case switchRiding
        case reception
        var id: String { rawValue }
    }

    let id: String
    let level: Level
    let category: Category
    let stepCount: Int
    let tipCount: Int
    let requiresCoach: Bool

    @MainActor func name(_ lang: LanguageSettings) -> String { lang.t("trick.\(id).name") }
    @MainActor func summary(_ lang: LanguageSettings) -> String { lang.t("trick.\(id).summary") }
    @MainActor func safety(_ lang: LanguageSettings) -> String { lang.t("trick.\(id).safety") }
    @MainActor func steps(_ lang: LanguageSettings) -> [String] {
        (0..<stepCount).map { lang.t("trick.\(id).step.\($0)") }
    }
    @MainActor func tips(_ lang: LanguageSettings) -> [String] {
        (0..<tipCount).map { lang.t("trick.\(id).tip.\($0)") }
    }
    @MainActor func levelName(_ lang: LanguageSettings) -> String { lang.t("level.\(level.rawValue)") }
    @MainActor func categoryName(_ lang: LanguageSettings) -> String { lang.t("cat.\(category.rawValue)") }
}

enum TrickLibrary {
    static let tricks: [Trick] = [
        Trick(id: "park-rules", level: .debutant, category: .securite, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "protections", level: .debutant, category: .securite, stepCount: 4, tipCount: 2, requiresCoach: false),
        Trick(id: "fall-better", level: .debutant, category: .securite, stepCount: 4, tipCount: 2, requiresCoach: false),
        Trick(id: "read-jump", level: .debutant, category: .sauts, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "straight-air", level: .debutant, category: .sauts, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "landing", level: .debutant, category: .reception, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "ollie", level: .debutant, category: .pop, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "safety-grab", level: .debutant, category: .grabs, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "box-5050", level: .debutant, category: .rails, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "one-eighty", level: .intermediaire, category: .rotations, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "switch-riding", level: .intermediaire, category: .switchRiding, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "nollie", level: .intermediaire, category: .pop, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "mute", level: .intermediaire, category: .grabs, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "three-sixty", level: .intermediaire, category: .rotations, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "nose-butter", level: .intermediaire, category: .butters, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "tail-butter", level: .intermediaire, category: .butters, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "rail-5050", level: .intermediaire, category: .rails, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "absorb", level: .intermediaire, category: .reception, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "slide", level: .avance, category: .rails, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "japan", level: .avance, category: .grabs, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "switch-180", level: .avance, category: .switchRiding, stepCount: 5, tipCount: 2, requiresCoach: false),
        Trick(id: "five-forty", level: .expert, category: .rotations, stepCount: 5, tipCount: 2, requiresCoach: true),
        Trick(id: "inversion-order", level: .expert, category: .securite, stepCount: 5, tipCount: 2, requiresCoach: true),
        Trick(id: "backflip", level: .expert, category: .sauts, stepCount: 6, tipCount: 3, requiresCoach: true),
        Trick(id: "frontflip", level: .expert, category: .sauts, stepCount: 6, tipCount: 3, requiresCoach: true),
        Trick(id: "cork-360", level: .expert, category: .rotations, stepCount: 6, tipCount: 2, requiresCoach: true),
    ]

    static func trick(_ id: String) -> Trick? {
        tricks.first { $0.id == id }
    }
}
