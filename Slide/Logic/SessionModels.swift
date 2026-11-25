import Foundation

struct DetectorConfig: Equatable {
    var maxHorizontalAccuracy = 30.0
    /// Au-delà, le point est un saut GPS, pas un skieur (198 km/h).
    var maxSpeed = 55.0
    var minDt = 0.35
    /// Au-delà, on coupe le trait : trou de GPS ou pause, pas une ligne droite.
    var maxGap = 45.0
    var stationarySlack = 2.0
    var accuracyNoiseFactor = 0.45
    var speedAlpha = 0.4
    var altitudeAlpha = 0.45
    var restSpeed = 1.15
    var skiSpeed = 2.6
    var fastSkiSpeed = 8.0
    var descentRate = -0.55
    var liftRate = 0.5
    var liftMinSpeed = 0.8
    var liftMaxSpeed = 9.0
    var trendWindow = 6.0
    var minTrendSpan = 3.0
    var hold = 4.0
    var minRunDuration = 8.0
    var minRunDistance = 25.0
    var minRunVertical = 8.0
    var spikeResetCount = 4
}

struct GeoSample: Equatable, Codable {
    var time: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var gpsSpeed: Double?

    init(
        time: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        gpsSpeed: Double? = nil
    ) {
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.gpsSpeed = gpsSpeed
    }
}

enum RejectReason: String, Equatable, Error {
    case nonFinite
    case badAccuracy
    case timeWentBackwards
    case tooSoon
    case speedSpike
}

enum TrackPhase: String, Codable, Equatable {
    case unknown
    case skiing
    case lift
    case rest
}

struct TrackSample: Equatable, Codable, Identifiable {
    var id: UUID
    var time: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var rawAltitude: Double
    var speed: Double
    var accuracy: Double
    var segmentDistance: Double
    var phase: TrackPhase

    init(
        id: UUID = UUID(),
        time: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        rawAltitude: Double,
        speed: Double,
        accuracy: Double,
        segmentDistance: Double,
        phase: TrackPhase = .unknown
    ) {
        self.id = id
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.rawAltitude = rawAltitude
        self.speed = speed
        self.accuracy = accuracy
        self.segmentDistance = segmentDistance
        self.phase = phase
    }
}

struct RunRecord: Equatable, Codable, Identifiable {
    var id: UUID
    var index: Int
    var startedAt: Date
    var endedAt: Date
    var maxSpeed: Double
    var avgSpeed: Double
    var distance: Double
    var verticalDrop: Double
    var duration: TimeInterval

    init(
        id: UUID = UUID(),
        index: Int,
        startedAt: Date,
        endedAt: Date,
        maxSpeed: Double,
        avgSpeed: Double,
        distance: Double,
        verticalDrop: Double,
        duration: TimeInterval
    ) {
        self.id = id
        self.index = index
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.maxSpeed = maxSpeed
        self.avgSpeed = avgSpeed
        self.distance = distance
        self.verticalDrop = verticalDrop
        self.duration = duration
    }
}

struct JumpRecord: Equatable, Codable, Identifiable {
    var id: UUID
    var time: Date
    var duration: TimeInterval

    init(id: UUID = UUID(), time: Date, duration: TimeInterval) {
        self.id = id
        self.time = time
        self.duration = duration
    }
}

struct LiveSummary: Equatable {
    var speed = 0.0
    var altitude = 0.0
    var hasFix = false
    var phase: TrackPhase = .unknown
    var distance = 0.0
    var vertical = 0.0
    var maxSpeed = 0.0
    var qualifiedRuns = 0
    var openRun: RunRecord?
    var accuracy = -1.0

    static let empty = LiveSummary()
}

struct IngestOutcome: Equatable {
    var accepted: Bool
    var reason: RejectReason?
    var phase: TrackPhase
    var qualifiedRuns: Int
}

struct SessionArchive: Equatable, Codable, Identifiable {
    static let currentVersion = 1

    var version: Int
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var resort: String
    var riderName: String
    var isComplete: Bool
    var isSample: Bool
    var raw: [GeoSample]
    var samples: [TrackSample]
    var runs: [RunRecord]
    var jumps: [JumpRecord]
    var maxSpeed: Double
    var distance: Double
    var vertical: Double
    var duration: TimeInterval

    var jumpCount: Int { jumps.count }
    var airtime: TimeInterval { jumps.reduce(0) { $0 + $1.duration } }
    var longestRunDistance: Double { runs.map(\.distance).max() ?? 0 }
}

enum SessionFile {
    static func encode(_ archive: SessionArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> SessionArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionArchive.self, from: data)
    }
}
