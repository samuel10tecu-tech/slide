import Foundation
import SwiftData

@Model
final class SkiDay {
    var uuid: UUID
    var startedAt: Date
    var endedAt: Date?
    var resort: String
    var riderName: String
    var isComplete: Bool
    var isSample: Bool
    var maxSpeed: Double
    var distance: Double
    var vertical: Double
    var duration: TimeInterval
    var runCount: Int
    var jumpCount: Int
    var airtime: TimeInterval
    var longestRunDistance: Double
    @Attribute(.externalStorage) var payload: Data

    init(archive: SessionArchive) {
        uuid = archive.id
        startedAt = archive.startedAt
        endedAt = archive.endedAt
        resort = archive.resort
        riderName = archive.riderName
        isComplete = archive.isComplete
        isSample = archive.isSample
        maxSpeed = archive.maxSpeed
        distance = archive.distance
        vertical = archive.vertical
        duration = archive.duration
        runCount = archive.runs.count
        jumpCount = archive.jumps.count
        airtime = archive.airtime
        longestRunDistance = archive.longestRunDistance
        payload = Data()
        write(archive)
    }

    func readArchive() -> SessionArchive? {
        if let inflated = try? payload.decompressed(using: .zlib),
           let archive = try? SessionFile.decode(inflated) {
            return archive
        }
        return try? SessionFile.decode(payload)
    }

    func write(_ archive: SessionArchive) {
        startedAt = archive.startedAt
        endedAt = archive.endedAt
        resort = archive.resort
        riderName = archive.riderName
        isComplete = archive.isComplete
        isSample = archive.isSample
        maxSpeed = archive.maxSpeed
        distance = archive.distance
        vertical = archive.vertical
        duration = archive.duration
        runCount = archive.runs.count
        jumpCount = archive.jumps.count
        airtime = archive.airtime
        longestRunDistance = archive.longestRunDistance
        if let encoded = try? SessionFile.encode(archive) {
            payload = (try? encoded.compressed(using: .zlib)) ?? encoded
        }
    }
}

@Model
final class TrickEntry {
    var trickId: String
    var learned: Bool
    var learnedAt: Date?
    var note: String
    var updatedAt: Date

    init(trickId: String, learned: Bool, learnedAt: Date?, note: String, updatedAt: Date = .now) {
        self.trickId = trickId
        self.learned = learned
        self.learnedAt = learnedAt
        self.note = note
        self.updatedAt = updatedAt
    }
}

@Model
final class RiderProfile {
    var name: String
    var homeMountain: String
    var speedMetric: Bool
    var distanceMetric: Bool
    var altitudeMetric: Bool
    var keepScreenOn: Bool

    init(
        name: String = "",
        homeMountain: String = "",
        speedMetric: Bool = true,
        distanceMetric: Bool = true,
        altitudeMetric: Bool = true,
        keepScreenOn: Bool = false
    ) {
        self.name = name
        self.homeMountain = homeMountain
        self.speedMetric = speedMetric
        self.distanceMetric = distanceMetric
        self.altitudeMetric = altitudeMetric
        self.keepScreenOn = keepScreenOn
    }

    var prefs: UnitPrefs {
        UnitPrefs(speedMetric: speedMetric, distanceMetric: distanceMetric, altitudeMetric: altitudeMetric)
    }
}

enum DayStore {
    static func all(in context: ModelContext) -> [SkiDay] {
        (try? context.fetch(FetchDescriptor<SkiDay>())) ?? []
    }

    static func upsert(_ archive: SessionArchive, in context: ModelContext) {
        if let existing = all(in: context).first(where: { $0.uuid == archive.id }) {
            existing.write(archive)
        } else {
            context.insert(SkiDay(archive: archive))
        }
        try? context.save()
    }

    static func profile(in context: ModelContext) -> RiderProfile {
        if let existing = (try? context.fetch(FetchDescriptor<RiderProfile>()))?.first {
            return existing
        }
        let created = RiderProfile()
        context.insert(created)
        try? context.save()
        return created
    }

    static func archive(from tracker: SessionTracker, jumps: [JumpRecord], id: UUID, startedAt: Date, endedAt: Date?, resort: String, riderName: String, isComplete: Bool, isSample: Bool, duration: TimeInterval) -> SessionArchive {
        let summary = tracker.summary
        return SessionArchive(
            version: SessionArchive.currentVersion,
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            resort: resort,
            riderName: riderName,
            isComplete: isComplete,
            isSample: isSample,
            raw: tracker.raw,
            samples: tracker.samples,
            runs: tracker.runs,
            jumps: jumps,
            maxSpeed: summary.maxSpeed,
            distance: summary.distance,
            vertical: summary.vertical,
            duration: duration
        )
    }
}

struct SeasonRollup: Equatable {
    var season: Season
    var days: Int
    var runs: Int
    var distance: Double
    var vertical: Double
    var topSpeed: Double
    var topSpeedDate: Date?
    var longestRun: Double
    var longestRunDate: Date?
    var bestDayVertical: Double
    var bestDayDate: Date?

    static let empty = SeasonRollup(
        season: Season.containing(.now),
        days: 0, runs: 0, distance: 0, vertical: 0,
        topSpeed: 0, topSpeedDate: nil,
        longestRun: 0, longestRunDate: nil,
        bestDayVertical: 0, bestDayDate: nil
    )

    static func make(days: [SkiDay], season: Season) -> SeasonRollup {
        let inside = days.filter { season.contains($0.startedAt) && $0.runCount >= 0 }
        var rollup = SeasonRollup(
            season: season,
            days: inside.count,
            runs: inside.reduce(0) { $0 + $1.runCount },
            distance: inside.reduce(0) { $0 + $1.distance },
            vertical: inside.reduce(0) { $0 + $1.vertical },
            topSpeed: 0,
            topSpeedDate: nil,
            longestRun: 0,
            longestRunDate: nil,
            bestDayVertical: 0,
            bestDayDate: nil
        )
        for day in inside {
            if day.maxSpeed > rollup.topSpeed {
                rollup.topSpeed = day.maxSpeed
                rollup.topSpeedDate = day.startedAt
            }
            if day.longestRunDistance > rollup.longestRun {
                rollup.longestRun = day.longestRunDistance
                rollup.longestRunDate = day.startedAt
            }
            if day.vertical > rollup.bestDayVertical {
                rollup.bestDayVertical = day.vertical
                rollup.bestDayDate = day.startedAt
            }
        }
        return rollup
    }
}
