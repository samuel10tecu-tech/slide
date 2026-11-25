import CoreLocation
import Foundation
import SwiftData

enum Activity: Equatable {
    case idle
    case tracking
    case paused
}

@MainActor
@Observable
final class TrackingController {
    private(set) var activity: Activity = .idle
    private(set) var summary = LiveSummary.empty
    private(set) var jumpCount = 0
    private(set) var airtime = 0.0
    private(set) var usingBarometer = false
    private(set) var resort = ""
    private(set) var startedAt: Date?
    private(set) var lastFixAt: Date?
    private(set) var auth: CLAuthorizationStatus = .notDetermined
    private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private(set) var notice: AppNotice?
    private(set) var lastArchive: SessionArchive?
    private(set) var mapSamples: [TrackSample] = []

    var recoverableID: UUID?
    var recoverableTitle = ""

    private var tracker = SessionTracker()
    private var lookedUpResort = false
    private let geocoder = CLGeocoder()
    private var airtimeDetector = AirtimeDetector()
    private var jumps: [JumpRecord] = []
    private var dayID: UUID?
    private var riderName = ""
    private var pauseAccumulated: TimeInterval = 0
    private var pauseStarted: Date?
    private var acceptedSinceFlush = 0
    private var lastFlush: Date?
    private var context: ModelContext?
    private var pendingStart = false
    private var askedAlways = false
    private var baroOriginGPS: Double?
    private var baroOriginRel: Double?
    private var latestRelative: Double?
    private var powerObserver: NSObjectProtocol?
    private var language: LanguageSettings?
    private let audio = AudioCoach()
    private var personalBest = 0.0
    private let liveActivity = LiveActivityBridge()
    private var lastMapPush = Date.distantPast

    private let location = LocationService()
    private let altimeter = AltimeterService()
    private let motion = MotionService()

    init() {
        location.onLocations = { [weak self] locations in
            self?.ingest(locations)
        }
        location.onAuthorization = { [weak self] status in
            self?.authorizationChanged(status)
        }
        location.onFailure = { [weak self] _ in
            self?.notice = .locationDenied
        }
        altimeter.onRelative = { [weak self] meters in
            self?.latestRelative = meters
            self?.usingBarometer = true
        }
        motion.onSample = { [weak self] time, magnitude in
            self?.ingestMotion(time: time, magnitude: magnitude)
        }
        auth = location.currentStatus
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    var isActive: Bool { activity != .idle }

    func duration(at now: Date) -> TimeInterval {
        if activity == .idle, let archive = lastArchive {
            return archive.duration
        }
        guard let startedAt else { return 0 }
        let end = activity == .paused ? (pauseStarted ?? now) : now
        return max(0, end.timeIntervalSince(startedAt) - pauseAccumulated)
    }

    func bind(context: ModelContext, language: LanguageSettings) {
        self.context = context
        self.language = language
        auth = location.currentStatus
        refreshRecovery()
    }

    func clearNotice() {
        notice = nil
    }

    func requestPermissionThenStart(resort: String, rider: String) {
        self.resort = resort
        riderName = rider
        switch location.currentStatus {
        case .notDetermined:
            pendingStart = true
            location.requestWhenInUse()
        case .denied, .restricted:
            notice = .locationBlocked
        default:
            begin()
            if location.currentStatus == .authorizedWhenInUse && !askedAlways {
                askedAlways = true
                location.requestAlways()
            }
        }
    }

    func pause() {
        guard activity == .tracking else { return }
        pauseStarted = Date()
        activity = .paused
        stopSensors()
        flush(complete: false)
        publish()
        pushLiveActivity(force: true)
    }

    func resume() {
        guard activity == .paused else { return }
        if let pauseStarted {
            pauseAccumulated += Date().timeIntervalSince(pauseStarted)
        }
        self.pauseStarted = nil
        activity = .tracking
        startSensors()
        publish()
    }

    func stop() {
        guard activity != .idle else { return }
        if let pauseStarted {
            pauseAccumulated += Date().timeIntervalSince(pauseStarted)
            self.pauseStarted = nil
        }
        stopSensors()
        liveActivity.end()
        mapSamples = tracker.samples
        if tracker.samples.isEmpty {
            deleteCurrentDay()
            lastArchive = nil
        } else {
            flush(complete: true)
        }
        activity = .idle
        refreshRecovery()
        publish()
    }

    func refreshRecovery() {
        guard activity == .idle, let context else {
            if activity != .idle {
                recoverableID = nil
            }
            return
        }
        let open = DayStore.all(in: context)
            .filter { !$0.isComplete }
            .sorted { $0.startedAt > $1.startedAt }
        if let day = open.first {
            recoverableID = day.uuid
            let place = day.resort.isEmpty ? "Sortie" : day.resort
            recoverableTitle = "\(place) · \(FormatFR.clock(day.startedAt))"
        } else {
            recoverableID = nil
            recoverableTitle = ""
        }
    }

    func resumeRecovered() {
        guard activity == .idle, let context, let id = recoverableID,
              let day = DayStore.all(in: context).first(where: { $0.uuid == id }),
              let archive = day.readArchive()
        else { return }
        tracker = SessionTracker.replay(archive.raw)
        jumps = archive.jumps
        dayID = day.uuid
        startedAt = archive.startedAt
        resort = day.resort
        riderName = archive.riderName
        let wall = Date().timeIntervalSince(archive.startedAt)
        pauseAccumulated = max(0, wall - archive.duration)
        pauseStarted = nil
        lastArchive = nil
        recoverableID = nil
        activity = .tracking
        startSensors()
        publish()
    }

    func closeRecovered() {
        guard let context, let id = recoverableID,
              let day = DayStore.all(in: context).first(where: { $0.uuid == id })
        else { return }
        if var archive = day.readArchive() {
            archive.isComplete = true
            archive.endedAt = archive.endedAt ?? Date()
            day.write(archive)
        } else {
            day.isComplete = true
            day.endedAt = Date()
        }
        try? context.save()
        recoverableID = nil
        refreshRecovery()
    }

    func importURL(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            notice = .fileUnreadable
            return
        }
        importData(data, filename: url.lastPathComponent)
    }

    func importData(_ data: Data, filename: String) {
        guard let context else {
            notice = .memoryNotReady
            return
        }
        let lower = filename.lowercased()
        let looksLikeSession = lower.hasSuffix(".slide") || lower.hasSuffix(".glisse")
        let looksLikeGPX = !looksLikeSession && (lower.hasSuffix(".gpx")
            || data.prefix(300).contains(Data("<gpx".utf8))
            || data.prefix(400).contains(Data("trkpt".utf8)))
        if looksLikeGPX {
            guard let xml = String(data: data, encoding: .utf8) else {
                notice = .fileUnreadable
                return
            }
            do {
                let samples = try GPXCodec.parse(xml)
                let replayed = SessionTracker.replay(samples)
                let started = samples.first?.time ?? Date()
                let ended = samples.last?.time ?? started
                let summary = replayed.summary
                let archive = SessionArchive(
                    version: SessionArchive.currentVersion,
                    id: UUID(),
                    startedAt: started,
                    endedAt: ended,
                    resort: "",
                    riderName: riderName,
                    isComplete: true,
                    isSample: false,
                    raw: replayed.raw,
                    samples: replayed.samples,
                    runs: replayed.runs,
                    jumps: [],
                    maxSpeed: summary.maxSpeed,
                    distance: summary.distance,
                    vertical: summary.vertical,
                    duration: max(0, ended.timeIntervalSince(started))
                )
                DayStore.upsert(archive, in: context)
                notice = .gpxImported(archive.runs.count)
            } catch {
                notice = .fileUnreadable
            }
            return
        }
        do {
            var archive = try SessionFile.decode(data)
            if DayStore.all(in: context).contains(where: { $0.uuid == archive.id }) {
                archive.id = UUID()
            }
            archive.isSample = false
            archive.isComplete = true
            DayStore.upsert(archive, in: context)
            let name = archive.resort.isEmpty ? "Slide" : archive.resort
            notice = .sessionImported(name)
        } catch {
            notice = .fileUnknown
        }
    }

    func toggleSampleDay() -> AppNotice {
        guard let context else { return .sampleRetry }
        let samples = DayStore.all(in: context).filter(\.isSample)
        if !samples.isEmpty {
            samples.forEach { context.delete($0) }
            try? context.save()
            return .sampleRemoved
        }
        DayStore.upsert(SampleDay.make(), in: context)
        return .sampleAdded
    }

    func eraseAllDaysAndTricks() {
        guard let context else { return }
        stopSensors()
        liveActivity.end()
        activity = .idle
        DayStore.all(in: context).forEach { context.delete($0) }
        let tricks = (try? context.fetch(FetchDescriptor<TrickEntry>())) ?? []
        tricks.forEach { context.delete($0) }
        try? context.save()
        tracker = SessionTracker()
        jumps = []
        lastArchive = nil
        recoverableID = nil
        publish()
    }

    func flush() {
        flush(complete: false)
    }

    private func begin() {
        tracker = SessionTracker()
        jumps = []
        airtimeDetector.reset()
        dayID = UUID()
        startedAt = Date()
        pauseAccumulated = 0
        pauseStarted = nil
        acceptedSinceFlush = 0
        lastFlush = nil
        lastArchive = nil
        lastFixAt = nil
        lookedUpResort = false
        geocoder.cancelGeocode()
        notice = nil
        baroOriginGPS = nil
        baroOriginRel = nil
        latestRelative = nil
        activity = .tracking
        recoverableID = nil
        personalBest = ((try? context?.fetch(FetchDescriptor<SkiDay>())) ?? []).map(\.maxSpeed).max() ?? 0
        audio.resetSession(personalBest: personalBest)
        if AudioCoachSettings.isOn { audio.prepare() }
        startSensors()
        flush(complete: false)
        publish()
        if let state = makeActivityState() {
            liveActivity.start(resort: resort, state: state)
        }
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        auth = status
        if pendingStart {
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                pendingStart = false
                begin()
                if status == .authorizedWhenInUse && !askedAlways {
                    askedAlways = true
                    location.requestAlways()
                }
            case .denied, .restricted:
                pendingStart = false
                notice = .locationDenied
            default:
                break
            }
        }
    }

    private func startSensors() {
        baroOriginGPS = nil
        baroOriginRel = nil
        latestRelative = nil
        airtimeDetector.reset()
        location.start()
        altimeter.start()
        motion.start()
        usingBarometer = false
    }

    private func stopSensors() {
        location.stop()
        altimeter.stop()
        motion.stop()
    }

    private func ingest(_ locations: [CLLocation]) {
        guard activity == .tracking else { return }
        for fix in locations where fix.horizontalAccuracy >= 0 {
            let sample = GeoSample(
                time: fix.timestamp,
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude,
                altitude: fusedAltitude(fix),
                horizontalAccuracy: fix.horizontalAccuracy,
                gpsSpeed: fix.speed >= 0 ? fix.speed : nil
            )
            let outcome = tracker.ingest(sample)
            if outcome.accepted {
                lastFixAt = Date()
                acceptedSinceFlush += 1
                warmMapIfNeeded()
            }
        }
        publish()
        let due = lastFlush.map { Date().timeIntervalSince($0) > 20 } ?? true
        if acceptedSinceFlush >= 12 || due {
            flush(complete: false)
        }
    }

    private func fusedAltitude(_ fix: CLLocation) -> Double {
        guard let relative = latestRelative else {
            usingBarometer = false
            return fix.altitude
        }
        if baroOriginGPS == nil {
            if fix.verticalAccuracy > 0 && fix.verticalAccuracy < 25 {
                baroOriginGPS = fix.altitude
                baroOriginRel = relative
            } else {
                usingBarometer = true
                return fix.altitude
            }
        }
        guard let originGPS = baroOriginGPS, let originRel = baroOriginRel else {
            return fix.altitude
        }
        if fix.verticalAccuracy > 0 && fix.verticalAccuracy < 12 {
            let implied = fix.altitude - (relative - originRel)
            baroOriginGPS = originGPS * 0.97 + implied * 0.03
        }
        usingBarometer = true
        let base = baroOriginGPS ?? originGPS
        return base + (relative - originRel)
    }

    private func ingestMotion(time: TimeInterval, magnitude: Double) {
        guard activity == .tracking else { return }
        let armed = summary.speed > 5 || summary.phase == .skiing || summary.openRun != nil
        guard let hit = airtimeDetector.ingest(time: time, magnitudeG: magnitude, armed: armed) else { return }
        jumps.append(JumpRecord(time: Date(), duration: hit.duration))
        publish()
    }

    private var prefs = UnitPrefs.metric

    func use(prefs: UnitPrefs) {
        self.prefs = prefs
    }

    private func publish() {
        nameResortIfNeeded()
        summary = tracker.summary
        jumpCount = jumps.count
        airtime = jumps.reduce(0) { $0 + $1.duration }
        let now = Date()
        if mapSamples.count != tracker.samples.count && now.timeIntervalSince(lastMapPush) > 0.8 {
            mapSamples = tracker.samples
            lastMapPush = now
        }
        pushLiveActivity(force: false)
        if activity == .tracking, let language {
            let totals = todayTotals()
            audio.consider(
                summary: summary,
                runs: tracker.runs,
                todayDistance: totals.distance,
                personalBest: personalBest,
                elapsed: duration(at: Date()),
                language: language,
                prefs: prefs
            )
        }
    }

    func todayTotals() -> (distance: Double, vertical: Double, maxSpeed: Double, runs: Int) {
        let start = Calendar.zurich.startOfDay(for: Date())
        let stored = (try? context?.fetch(FetchDescriptor<SkiDay>())) ?? []
        var distance = 0.0
        var vertical = 0.0
        var maxSpeed = 0.0
        var runs = 0
        for day in stored where day.startedAt >= start {
            if activity != .idle, day.uuid == dayID { continue }
            distance += day.distance
            vertical += day.vertical
            maxSpeed = max(maxSpeed, day.maxSpeed)
            runs += day.runCount
        }
        if activity != .idle {
            distance += summary.distance
            vertical += summary.vertical
            maxSpeed = max(maxSpeed, summary.maxSpeed)
            runs += summary.qualifiedRuns
        }
        return (distance, vertical, maxSpeed, runs)
    }

    func speed(minutesAgo minutes: Int) -> Double? {
        let target = Date().addingTimeInterval(-Double(minutes) * 60)
        var best: (TimeInterval, Double)?
        func consider(time: Date, speed: Double) {
            let gap = abs(time.timeIntervalSince(target))
            if best == nil || gap < best!.0 { best = (gap, speed) }
        }
        for sample in tracker.samples { consider(time: sample.time, speed: sample.speed) }
        let start = Calendar.zurich.startOfDay(for: Date())
        let stored = (try? context?.fetch(FetchDescriptor<SkiDay>())) ?? []
        for day in stored where day.startedAt >= start {
            guard let archive = day.readArchive() else { continue }
            for sample in archive.samples { consider(time: sample.time, speed: sample.speed) }
        }
        guard let best, best.0 <= 180 else { return nil }
        return best.1
    }

    private func warmMapIfNeeded() {
        guard let last = tracker.samples.last else { return }
        if let lat = warmLat, let lon = warmLon {
            let moved = Geo.haversineMeters(lat1: lat, lon1: lon, lat2: last.latitude, lon2: last.longitude)
            if moved < 1_500 { return }
        }
        warmLat = last.latitude
        warmLon = last.longitude
        MapCache.warm(around: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
    }

    private var warmLat: Double?
    private var warmLon: Double?

    private func makeActivityState() -> SlideActivityAttributes.ContentState? {
        guard let lang = language else { return nil }
        let phase: String
        switch activity {
        case .paused:
            phase = lang.t("tracking.phase.pause")
        case .tracking:
            phase = lang.t(Self.phaseKey(summary.phase))
        case .idle:
            phase = lang.t("tracking.phase.ready")
        }
        let altitude = summary.hasFix
            ? FormatFR.altitude(summary.altitude, prefs: prefs, french: lang.frenchNumbers)
            : "—"
        return SlideActivityAttributes.ContentState(
            speedText: FormatFR.speed(summary.speed, prefs: prefs, french: lang.frenchNumbers),
            unitText: FormatFR.speedUnit(prefs),
            altitudeText: altitude,
            phaseText: phase
        )
    }

    private func pushLiveActivity(force: Bool) {
        guard activity != .idle, let state = makeActivityState() else { return }
        liveActivity.update(state, force: force)
    }

    private static func phaseKey(_ phase: TrackPhase) -> String {
        switch phase {
        case .unknown: return "tracking.phase.calibration"
        case .skiing: return "tracking.phase.skiing"
        case .lift: return "tracking.phase.lift"
        case .rest: return "tracking.phase.rest"
        }
    }

    private func nameResortIfNeeded() {
        guard resort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard tracker.samples.count >= 8 else { return }
        if let place = ResortIndex.match(samples: tracker.samples) {
            resort = place.name
            return
        }
        guard !lookedUpResort, let last = tracker.samples.last else { return }
        lookedUpResort = true
        let location = CLLocation(latitude: last.latitude, longitude: last.longitude)
        geocoder.reverseGeocodeLocation(location) { marks, _ in
            let found = marks?.first?.locality ?? marks?.first?.subLocality ?? marks?.first?.name ?? ""
            let trimmed = found.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            Task { @MainActor in
                if self.resort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.resort = trimmed
                    self.flush(complete: false)
                }
            }
        }
    }

    private func flush(complete: Bool) {
        // Un flush en arrière-plan ne doit pas rouvrir une sortie déjà terminée.
        guard activity != .idle || complete else { return }
        guard let context, let dayID, let startedAt else { return }
        if tracker.samples.isEmpty && !complete { return }
        var resortName = resort.trimmingCharacters(in: .whitespacesAndNewlines)
        if resortName.isEmpty,
           let existing = DayStore.all(in: context).first(where: { $0.uuid == dayID }),
           !existing.resort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resortName = existing.resort
            resort = existing.resort
        }
        let ended = complete ? Date() : nil
        let archive = DayStore.archive(
            from: tracker,
            jumps: jumps,
            id: dayID,
            startedAt: startedAt,
            endedAt: ended,
            resort: resortName,
            riderName: riderName,
            isComplete: complete,
            isSample: false,
            duration: duration(at: Date())
        )
        DayStore.upsert(archive, in: context)
        if complete {
            lastArchive = archive
        }
        acceptedSinceFlush = 0
        lastFlush = Date()
    }

    private func deleteCurrentDay() {
        guard let context, let dayID else { return }
        if let day = DayStore.all(in: context).first(where: { $0.uuid == dayID }) {
            context.delete(day)
            try? context.save()
        }
    }
}
