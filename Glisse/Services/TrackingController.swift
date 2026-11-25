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
    private(set) var locationError: String?
    private(set) var lastArchive: SessionArchive?
    private(set) var importNote: String?

    var recoverableID: UUID?
    var recoverableTitle = ""

    private var tracker = SessionTracker()
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
        location.onFailure = { [weak self] message in
            self?.locationError = message
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

    func bind(context: ModelContext) {
        self.context = context
        auth = location.currentStatus
        refreshRecovery()
    }

    func clearImportNote() {
        importNote = nil
    }

    func requestPermissionThenStart(resort: String, rider: String) {
        self.resort = resort
        riderName = rider
        switch location.currentStatus {
        case .notDetermined:
            pendingStart = true
            location.requestWhenInUse()
        case .denied, .restricted:
            locationError = "La localisation est bloquée. Active-la dans Réglages pour tracer une sortie."
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
            importNote = "Impossible de lire ce fichier."
            return
        }
        importData(data, filename: url.lastPathComponent)
    }

    func importData(_ data: Data, filename: String) {
        guard let context else {
            importNote = "La mémoire de l'app n'est pas prête."
            return
        }
        let lower = filename.lowercased()
        let looksLikeGPX = lower.hasSuffix(".gpx")
            || data.prefix(300).contains(Data("<gpx".utf8))
            || data.prefix(400).contains(Data("trkpt".utf8))
        if looksLikeGPX {
            guard let xml = String(data: data, encoding: .utf8) else {
                importNote = "Ce GPX n'est pas lisible."
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
                    resort: "Trace importée",
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
                importNote = "Trace importée · \(archive.runs.count) descente\(archive.runs.count > 1 ? "s" : "")."
            } catch {
                importNote = "Ce GPX est vide ou illisible."
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
            importNote = "Sortie importée · \(archive.resort.isEmpty ? "sans nom" : archive.resort)."
        } catch {
            importNote = "Fichier inconnu. Glisse lit le GPX et les fichiers .glisse."
        }
    }

    func toggleSampleDay() -> String {
        guard let context else { return "Réessaie dans une seconde." }
        let samples = DayStore.all(in: context).filter(\.isSample)
        if !samples.isEmpty {
            samples.forEach { context.delete($0) }
            try? context.save()
            return "Journée d'exemple retirée."
        }
        DayStore.upsert(SampleDay.make(), in: context)
        return "Journée d'exemple ajoutée dans l'historique."
    }

    func eraseAllDaysAndTricks() {
        guard let context else { return }
        stopSensors()
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
        locationError = nil
        baroOriginGPS = nil
        baroOriginRel = nil
        latestRelative = nil
        activity = .tracking
        recoverableID = nil
        startSensors()
        flush(complete: false)
        publish()
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
                locationError = "Sans la position, Glisse ne peut pas mesurer la vitesse."
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

    private func publish() {
        summary = tracker.summary
        jumpCount = jumps.count
        airtime = jumps.reduce(0) { $0 + $1.duration }
    }

    private func flush(complete: Bool) {
        // Un flush en arrière-plan ne doit pas rouvrir une sortie déjà terminée.
        guard activity != .idle || complete else { return }
        guard let context, let dayID, let startedAt else { return }
        if tracker.samples.isEmpty && !complete { return }
        let ended = complete ? Date() : nil
        let archive = DayStore.archive(
            from: tracker,
            jumps: jumps,
            id: dayID,
            startedAt: startedAt,
            endedAt: ended,
            resort: resort,
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
