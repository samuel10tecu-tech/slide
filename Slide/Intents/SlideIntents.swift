import AppIntents
import Foundation
import SwiftData

@MainActor
enum SlideServices {
    static let controller = TrackingController()
    static let language = LanguageSettings()
}

enum SlideAnswers {
    @MainActor
    static func maxToday() -> String {
        let totals = SlideServices.controller.todayTotals()
        let lang = SlideServices.language
        guard totals.maxSpeed > 0 else { return lang.t("siri.max.none") }
        return lang.t("siri.max", spokenSpeed(totals.maxSpeed))
    }

    @MainActor
    static func distanceToday() -> String {
        let lang = SlideServices.language
        return lang.t("siri.distance", spokenDistance(SlideServices.controller.todayTotals().distance))
    }

    @MainActor
    static func currentSpeed() -> String {
        let controller = SlideServices.controller
        let lang = SlideServices.language
        guard controller.activity == .tracking else { return lang.t("siri.idle") }
        return lang.t("siri.speed.now", spokenSpeed(controller.summary.speed))
    }

    @MainActor
    static func speed(minutesAgo minutes: Int) -> String {
        let lang = SlideServices.language
        let minutes = min(180, max(1, minutes))
        guard let speed = SlideServices.controller.speed(minutesAgo: minutes) else {
            return lang.t("siri.speed.missing", Int32(minutes))
        }
        return lang.t("siri.speed.ago", spokenSpeed(speed), Int32(minutes))
    }

    @MainActor
    static func runsToday() -> String {
        let lang = SlideServices.language
        return lang.t("siri.runs", Int32(SlideServices.controller.todayTotals().runs))
    }

    @MainActor
    static func start() -> String {
        let controller = SlideServices.controller
        let lang = SlideServices.language
        controller.bind(context: AppContainer.shared.mainContext, language: lang)
        if controller.activity == .tracking { return lang.t("siri.already") }
        let profiles = (try? AppContainer.shared.mainContext.fetch(FetchDescriptor<RiderProfile>())) ?? []
        let profile = profiles.first
        controller.requestPermissionThenStart(resort: profile?.homeMountain ?? "", rider: profile?.name ?? "")
        if controller.activity == .tracking { return lang.t("siri.started") }
        return lang.t("siri.denied")
    }

    @MainActor
    static func stop() -> String {
        let controller = SlideServices.controller
        let lang = SlideServices.language
        guard controller.activity != .idle else { return lang.t("siri.idle") }
        controller.stop()
        return lang.t("siri.stopped")
    }

    @MainActor
    private static func spokenSpeed(_ metersPerSecond: Double) -> String {
        let prefs = currentPrefs()
        let lang = SlideServices.language
        return FormatFR.speed(metersPerSecond, prefs: prefs, french: lang.frenchNumbers) + " " + FormatFR.speedUnit(prefs)
    }

    @MainActor
    private static func spokenDistance(_ meters: Double) -> String {
        let prefs = currentPrefs()
        return FormatFR.distance(meters, prefs: prefs, french: SlideServices.language.frenchNumbers)
    }

    @MainActor
    private static func currentPrefs() -> UnitPrefs {
        let profiles = (try? AppContainer.shared.mainContext.fetch(FetchDescriptor<RiderProfile>())) ?? []
        return profiles.first?.prefs ?? .metric
    }
}

struct MaxSpeedTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.max"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.maxToday() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct DistanceTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.distance"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.distanceToday() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct CurrentSpeedIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.now"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.currentSpeed() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

enum MinutesAgo: Int, AppEnum {
    case one = 1
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Minutes")
    static var caseDisplayRepresentations: [MinutesAgo: DisplayRepresentation] = [
        .one: "1",
        .five: "5",
        .ten: "10",
        .fifteen: "15",
        .thirty: "30"
    ]
}

struct SpeedAgoIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.ago"
    static var openAppWhenRun = true
    @Parameter(title: "siri.param.minutes", default: MinutesAgo.five)
    var minutes: MinutesAgo
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = minutes.rawValue
        let text = await MainActor.run { SlideAnswers.speed(minutesAgo: count) }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct RunsTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.runs"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.runsToday() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct StartTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.start"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.start() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct StopTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.title.stop"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { SlideAnswers.stop() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct SlideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MaxSpeedTodayIntent(),
            phrases: ["Max speed today in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.max"),
            systemImageName: "gauge.with.needle"
        )
        AppShortcut(
            intent: DistanceTodayIntent(),
            phrases: ["Distance today in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.distance"),
            systemImageName: "ruler"
        )
        AppShortcut(
            intent: SpeedAgoIntent(),
            phrases: ["Speed \(\.$minutes) minutes ago in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.ago"),
            systemImageName: "clock"
        )
        AppShortcut(
            intent: CurrentSpeedIntent(),
            phrases: ["Current speed in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.now"),
            systemImageName: "speedometer"
        )
        AppShortcut(
            intent: RunsTodayIntent(),
            phrases: ["Runs today in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.runs"),
            systemImageName: "mountain.2"
        )
        AppShortcut(
            intent: StartTrackingIntent(),
            phrases: ["Start tracking in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.start"),
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopTrackingIntent(),
            phrases: ["Stop tracking in \(.applicationName)"],
            shortTitle: LocalizedStringResource("siri.title.stop"),
            systemImageName: "stop.fill"
        )
    }
}
