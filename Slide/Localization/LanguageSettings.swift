import Foundation

enum AppNotice: Equatable {
    case fileUnreadable
    case fileUnknown
    case gpxImported(Int)
    case sessionImported(String)
    case memoryNotReady
    case locationBlocked
    case locationDenied
    case sampleAdded
    case sampleRemoved
    case sampleRetry

    func message(_ lang: LanguageSettings) -> String {
        switch self {
        case .fileUnreadable:
            return lang.t("notice.file.unreadable")
        case .fileUnknown:
            return lang.t("notice.file.unknown")
        case .gpxImported(let count):
            return lang.t("notice.gpx", Int32(count))
        case .sessionImported(let name):
            return lang.t("notice.session", name)
        case .memoryNotReady:
            return lang.t("notice.memory")
        case .locationBlocked:
            return lang.t("notice.location.blocked")
        case .locationDenied:
            return lang.t("notice.location.denied")
        case .sampleAdded:
            return lang.t("notice.sample.added")
        case .sampleRemoved:
            return lang.t("notice.sample.removed")
        case .sampleRetry:
            return lang.t("notice.sample.retry")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case fr
    case de
    case it
    case es
    case pt
    case nl
    case sv
    case nb
    case pl
    case cs
    case ja
    case ko
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    /// Name of the language, written in that language. The system row stays translated.
    var endonym: String {
        switch self {
        case .system: return ""
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .es: return "Español"
        case .pt: return "Português"
        case .nl: return "Nederlands"
        case .sv: return "Svenska"
        case .nb: return "Norsk"
        case .pl: return "Polski"
        case .cs: return "Čeština"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        }
    }

    static func matching(_ preferred: String) -> String {
        let tag = preferred.replacingOccurrences(of: "_", with: "-")
        let lower = tag.lowercased()
        if lower.hasPrefix("zh-hans") || lower.hasPrefix("zh-cn") || lower == "zh" {
            return AppLanguage.zhHans.rawValue
        }
        if lower.hasPrefix("pt") { return AppLanguage.pt.rawValue }
        if lower.hasPrefix("nb") || lower.hasPrefix("nn") || lower.hasPrefix("no") {
            return AppLanguage.nb.rawValue
        }
        let primary = lower.split(separator: "-").first.map(String.init) ?? "en"
        let supported: Set<String> = ["en", "fr", "de", "it", "es", "pt", "nl", "sv", "nb", "pl", "cs", "ja", "ko"]
        return supported.contains(primary) ? primary : "en"
    }
}

@MainActor
@Observable
final class LanguageSettings {
    private static let storageKey = "slide.language"

    var choice: AppLanguage {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        choice = AppLanguage(rawValue: raw) ?? .system
    }

    var code: String {
        switch choice {
        case .system:
            return AppLanguage.matching(Locale.preferredLanguages.first ?? "en")
        default:
            return choice.rawValue
        }
    }

    /// Comma decimals and a narrow space for thousands. English, Japanese, Korean and Chinese use a period.
    var frenchNumbers: Bool {
        switch code {
        case "en", "ja", "ko", "zh-Hans":
            return false
        default:
            return true
        }
    }

    var localeIdentifier: String {
        switch code {
        case "fr": return "fr_CH"
        case "de": return "de_DE"
        case "it": return "it_IT"
        case "es": return "es_ES"
        case "pt": return "pt_PT"
        case "nl": return "nl_NL"
        case "sv": return "sv_SE"
        case "nb": return "nb_NO"
        case "pl": return "pl_PL"
        case "cs": return "cs_CZ"
        case "ja": return "ja_JP"
        case "ko": return "ko_KR"
        case "zh-Hans": return "zh_Hans"
        default: return "en_GB"
        }
    }

    var swiftUILocale: Locale {
        Locale(identifier: localeIdentifier)
    }

    func t(_ key: String) -> String {
        let bundle = Self.bundle(for: code)
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if value != key {
            return value
        }
        if bundle !== Bundle.main {
            let fallback = Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
            return fallback
        }
        return key
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        let format = t(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: swiftUILocale, arguments: args)
    }

    private static func bundle(for code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
