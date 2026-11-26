import AVFoundation
import Foundation

enum AudioCoachSettings {
    static let enabled = "slide.audio.enabled"
    static let threshold = "slide.audio.threshold"
    static let everyKm = "slide.audio.everyKm"
    static let period = "slide.audio.period"
    static let partDistance = "slide.audio.part.distance"
    static let partSpeed = "slide.audio.part.speed"
    static let partMax = "slide.audio.part.max"
    static let partVertical = "slide.audio.part.vertical"
    static let partRuns = "slide.audio.part.runs"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: enabled) }
    static var thresholdKmh: Double {
        let value = UserDefaults.standard.double(forKey: threshold)
        return value == 0 ? 60 : value
    }
    static var every: Double {
        let value = UserDefaults.standard.double(forKey: everyKm)
        return value == 0 ? 1 : min(10, max(0.5, value))
    }
    static var periodMinutes: Int { Int(UserDefaults.standard.double(forKey: period)) }

    static func part(_ key: String, default value: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return value }
        return UserDefaults.standard.bool(forKey: key)
    }
}

@MainActor
final class AudioCoach: NSObject, AVSpeechSynthesizerDelegate {
    /// One coach for the whole app. A throwaway instance would be freed mid-sentence.
    static let shared = AudioCoach()

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }
    private var lastSpoken = Date.distantPast
    private var pending: String?
    private var primed = false
    private var thresholdArmed = true
    private var announcedDayMax = 0.0
    private var announcedPersonal = 0.0
    private var distanceBucket = 0
    private var lastPeriodic = Date.distantPast
    private var spokenRuns = 0

    func resetSession(personalBest: Double) {
        primed = false
        thresholdArmed = true
        announcedDayMax = 0
        announcedPersonal = personalBest
        distanceBucket = 0
        lastPeriodic = Date()
        spokenRuns = 0
        pending = nil
    }

    func prepare() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers, .mixWithOthers, .allowBluetoothA2DP]
        )
        try? session.setActive(true)
    }

    /// Give the audio back to music and podcasts at full volume.
    func release() {
        guard !synth.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.release() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.release() }
    }

    func test(language: LanguageSettings) {
        speak(language.t("audio.say.test"), code: language.code, force: true)
    }

    func consider(
        summary: LiveSummary,
        runs: [RunRecord],
        todayDistance: Double,
        personalBest: Double,
        elapsed: TimeInterval,
        language: LanguageSettings,
        prefs: UnitPrefs
    ) {
        guard AudioCoachSettings.isOn else { return }
        flushPending(language)
        if !primed {
            primed = true
            announcedDayMax = summary.maxSpeed
            announcedPersonal = max(personalBest, summary.maxSpeed)
            distanceBucket = bucket(for: todayDistance)
            spokenRuns = runs.count
            lastPeriodic = Date()
            return
        }

        let kmh = summary.speed * 3.6
        let mark = AudioCoachSettings.thresholdKmh
        if runs.count > spokenRuns || kmh < mark - 10 { thresholdArmed = true }
        var phrase: String?
        if runs.count > spokenRuns, let run = runs.last {
            spokenRuns = runs.count
            phrase = runLine(run, language: language, prefs: prefs)
        } else if summary.maxSpeed > announcedPersonal + 0.28 {
            announcedPersonal = summary.maxSpeed
            phrase = language.t("audio.say.record", speed(summary.maxSpeed, language, prefs))
        } else if summary.maxSpeed > announcedDayMax + 0.28 {
            announcedDayMax = summary.maxSpeed
            phrase = language.t("audio.say.day", speed(summary.maxSpeed, language, prefs))
        } else if thresholdArmed && kmh >= mark {
            thresholdArmed = false
            phrase = language.t("audio.say.over", speed(mark / 3.6, language, prefs))
        } else {
            let nextBucket = bucket(for: todayDistance)
            if nextBucket > distanceBucket {
                distanceBucket = nextBucket
                phrase = language.t("audio.say.distance", FormatFR.distance(todayDistance, prefs: prefs, french: language.frenchNumbers))
            } else if AudioCoachSettings.periodMinutes > 0,
                      Date().timeIntervalSince(lastPeriodic) >= Double(AudioCoachSettings.periodMinutes) * 60 {
                lastPeriodic = Date()
                phrase = ([language.t("audio.say.update")] + parts(summary, todayDistance, runs.count, elapsed, language, prefs)).joined(separator: " ")
            }
        }
        if let phrase { queue(phrase, language) }
        flushPending(language)
    }

    private func bucket(for meters: Double) -> Int {
        Int(meters / (AudioCoachSettings.every * 1000))
    }

    private func parts(
        _ summary: LiveSummary,
        _ todayDistance: Double,
        _ runCount: Int,
        _ elapsed: TimeInterval,
        _ language: LanguageSettings,
        _ prefs: UnitPrefs,
        includeSpeed: Bool = true,
        includeDistance: Bool = true
    ) -> [String] {
        var lines: [String] = []
        if includeDistance && AudioCoachSettings.part(AudioCoachSettings.partDistance, default: true) {
            lines.append(language.t("audio.say.distance", FormatFR.distance(todayDistance, prefs: prefs, french: language.frenchNumbers)))
        }
        if includeSpeed && AudioCoachSettings.part(AudioCoachSettings.partSpeed, default: true) {
            lines.append(language.t("audio.say.speed", speed(summary.speed, language, prefs)))
        }
        if AudioCoachSettings.part(AudioCoachSettings.partMax, default: true) {
            lines.append(language.t("audio.say.max", speed(summary.maxSpeed, language, prefs)))
        }
        if AudioCoachSettings.part(AudioCoachSettings.partVertical, default: true) {
            lines.append(language.t("audio.say.vertical", FormatFR.altitude(summary.vertical, prefs: prefs, french: language.frenchNumbers)))
        }
        if AudioCoachSettings.part(AudioCoachSettings.partRuns, default: true) {
            lines.append(language.t("audio.say.runs", Int32(runCount)))
        }
        if lines.isEmpty {
            lines.append(language.t("audio.say.speed", speed(summary.speed, language, prefs)))
        }
        return lines
    }

    private func runLine(_ run: RunRecord, language: LanguageSettings, prefs: UnitPrefs) -> String {
        [
            language.t("audio.say.run", Int32(run.index)),
            language.t("audio.say.max", speed(run.maxSpeed, language, prefs)),
            language.t("audio.say.distance", FormatFR.distance(run.distance, prefs: prefs, french: language.frenchNumbers)),
            language.t("audio.say.vertical", FormatFR.altitude(run.verticalDrop, prefs: prefs, french: language.frenchNumbers)),
        ].joined(separator: " ")
    }

    private func speed(_ metersPerSecond: Double, _ language: LanguageSettings, _ prefs: UnitPrefs) -> String {
        FormatFR.speed(metersPerSecond, prefs: prefs, french: language.frenchNumbers) + " " + FormatFR.speedUnit(prefs)
    }

    private func queue(_ text: String, _ language: LanguageSettings) {
        if Date().timeIntervalSince(lastSpoken) < 8 || synth.isSpeaking {
            pending = text
            return
        }
        speak(text, code: language.code, force: false)
    }

    private func flushPending(_ language: LanguageSettings) {
        guard let pending, Date().timeIntervalSince(lastSpoken) >= 8, !synth.isSpeaking else { return }
        self.pending = nil
        speak(pending, code: language.code, force: false)
    }

    private func speak(_ text: String, code: String, force: Bool) {
        if force { synth.stopSpeaking(at: .immediate) }
        prepare()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voice(code))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
        lastSpoken = Date()
    }

    static func voice(_ code: String) -> String {
        switch code {
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "it": return "it-IT"
        case "es": return "es-ES"
        case "pt": return "pt-PT"
        case "nl": return "nl-NL"
        case "sv": return "sv-SE"
        case "nb": return "nb-NO"
        case "pl": return "pl-PL"
        case "cs": return "cs-CZ"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "zh-Hans": return "zh-CN"
        default: return "en-GB"
        }
    }
}
