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

    var id: String { rawValue }
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
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("fr") ? "fr" : "en"
        case .en:
            return "en"
        case .fr:
            return "fr"
        }
    }

    var frenchNumbers: Bool { code == "fr" }

    var swiftUILocale: Locale {
        Locale(identifier: code == "fr" ? "fr_CH" : "en_GB")
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
