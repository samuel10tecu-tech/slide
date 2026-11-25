import Foundation
#if GLISSE_HOSTED_TESTS
@testable import Glisse
#endif

struct Check: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}

func expect(_ condition: Bool, _ message: String) throws {
    if !condition { throw Check(message: message) }
}

func expectClose(_ value: Double, _ target: Double, tol: Double, _ message: String) throws {
    if abs(value - target) > tol {
        throw Check(message: "\(message) — obtenu \(value), attendu \(target) ± \(tol)")
    }
}

private struct LCG {
    var state: UInt64
    mutating func unit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return Double(state >> 11) / Double(1 << 53)
    }
}

private struct TraceBuilder {
    var time: Date
    var lat: Double
    var lon: Double
    var alt: Double
    var samples: [GeoSample] = []

    mutating func leg(
        seconds: Int,
        north: Double,
        east: Double = 0,
        vertical: Double,
        accuracy: Double = 4,
        gpsSpeed: Double? = nil
    ) {
        let first = samples.isEmpty ? 0 : 1
        for index in first...seconds {
            let moved = Geo.project(
                lat: lat,
                lon: lon,
                north: north * Double(index),
                east: east * Double(index)
            )
            let speed = gpsSpeed ?? hypot(north, east)
            samples.append(GeoSample(
                time: time.addingTimeInterval(Double(index)),
                latitude: moved.lat,
                longitude: moved.lon,
                altitude: alt + vertical * Double(index),
                horizontalAccuracy: accuracy,
                gpsSpeed: speed
            ))
        }
        guard let last = samples.last else { return }
        lat = last.latitude
        lon = last.longitude
        alt = last.altitude
        time = last.time
    }
}

enum LogicChecks {
    static func all() throws {
        try haversineLatitudeDegree()
        try haversineZero()
        try projectRoundTrip()
        try rejectsBadAccuracy()
        try rejectsNonFinite()
        try rejectsTimeRegression()
        try rejectsSpeedSpikeWithoutAddingDistance()
        try jitterDoesNotInflateDistance()
        try gapDoesNotDrawStraightLine()
        try cleanDescentIsOneRun()
        try descentLiftDescentIsTwoRuns()
        try liftAloneIsNotARun()
        try shortBurstIsNotAQualifiedRun()
        try stationaryIsRest()
        try replayMatchesIncremental()
        try noisyDescentStillOneRun()
        try airtimeCountsArmedJump()
        try airtimeIgnoresTinyAndLongAndUnarmed()
        try gpxRoundTripCoordinates()
        try sessionFileRoundTrip()
        try seasonBoundaries()
        try speedBands()
        try durationAndDecimalFormat()
        try sampleDayHasSeveralRuns()
    }

    static func haversineLatitudeDegree() throws {
        let distance = Geo.haversineMeters(lat1: 0, lon1: 0, lat2: 1, lon2: 0)
        try expectClose(distance, 111_195, tol: 50, "1° de latitude")
    }

    static func haversineZero() throws {
        let distance = Geo.haversineMeters(lat1: 46.2, lon1: 6.14, lat2: 46.2, lon2: 6.14)
        try expectClose(distance, 0, tol: 0.001, "même point")
    }

    static func projectRoundTrip() throws {
        let moved = Geo.project(lat: 46.2, lon: 6.15, north: 1_000, east: -250)
        let distance = Geo.haversineMeters(lat1: 46.2, lon1: 6.15, lat2: moved.lat, lon2: moved.lon)
        try expectClose(distance, hypot(1_000, 250), tol: 3, "projection 1000 m N / 250 m O")
    }

    static func rejectsBadAccuracy() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.15, alt: 1_500)
        builder.leg(seconds: 8, north: 8, vertical: -1)
        let count = builder.samples.count
        builder.samples.append(GeoSample(
            time: builder.time.addingTimeInterval(1),
            latitude: builder.lat + 0.01,
            longitude: builder.lon,
            altitude: builder.alt,
            horizontalAccuracy: 80,
            gpsSpeed: 8
        ))
        let tracker = SessionTracker.replay(builder.samples)
        try expect(tracker.rejectedCount >= 1, "le point à 80 m doit être rejeté")
        try expect(tracker.samples.count == count, "le mauvais point ne doit pas entrer dans la trace")
    }

    static func rejectsNonFinite() throws {
        var filter = TrackFilter()
        let result = filter.push(GeoSample(
            time: Date(timeIntervalSince1970: 10),
            latitude: .nan,
            longitude: 6,
            altitude: 10,
            horizontalAccuracy: 5
        ))
        guard case .failure(.nonFinite) = result else {
            throw Check(message: "NaN doit être rejeté")
        }
    }

    static func rejectsTimeRegression() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var filter = TrackFilter()
        _ = filter.push(GeoSample(time: start, latitude: 46, longitude: 6, altitude: 1000, horizontalAccuracy: 5, gpsSpeed: 0))
        let result = filter.push(GeoSample(
            time: start.addingTimeInterval(-2),
            latitude: 46.0001,
            longitude: 6,
            altitude: 999,
            horizontalAccuracy: 5,
            gpsSpeed: 5
        ))
        guard case .failure(.timeWentBackwards) = result else {
            throw Check(message: "un temps qui recule doit être rejeté")
        }
    }

    static func rejectsSpeedSpikeWithoutAddingDistance() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.15, alt: 1_800)
        builder.leg(seconds: 20, north: 10, vertical: -1.2)
        var raw = builder.samples
        let original = raw[10]
        raw[10] = GeoSample(
            time: original.time,
            latitude: original.latitude + 0.02,
            longitude: original.longitude + 0.01,
            altitude: original.altitude,
            horizontalAccuracy: 6,
            gpsSpeed: 120
        )
        let tracker = SessionTracker.replay(raw)
        try expect(
            tracker.summary.distance < 350,
            "distance \(tracker.summary.distance) m : le pic GPS ne doit pas ajouter des kilomètres"
        )
        try expect(tracker.summary.distance > 120, "la trace réelle doit rester, distance \(tracker.summary.distance)")
        try expect(tracker.rejectedCount >= 1, "le pic doit être compté comme rejeté")
    }

    static func jitterDoesNotInflateDistance() throws {
        var rng = LCG(state: 42)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var samples: [GeoSample] = []
        for index in 0..<70 {
            let north = (rng.unit() - 0.5) * 6
            let east = (rng.unit() - 0.5) * 6
            let moved = Geo.project(lat: 46.2, lon: 6.8, north: north, east: east)
            samples.append(GeoSample(
                time: start.addingTimeInterval(Double(index)),
                latitude: moved.lat,
                longitude: moved.lon,
                altitude: 1_500 + (rng.unit() - 0.5) * 2,
                horizontalAccuracy: 15,
                gpsSpeed: 0
            ))
        }
        let tracker = SessionTracker.replay(samples)
        try expect(tracker.runs.isEmpty, "le bruit immobile ne doit pas créer de descente (\(tracker.runs.count))")
        try expect(
            tracker.summary.distance < 40,
            "distance gonflée par le bruit : \(tracker.summary.distance) m"
        )
    }

    static func gapDoesNotDrawStraightLine() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.15, alt: 1_600)
        builder.leg(seconds: 15, north: 10, vertical: -1.4)
        let far = Geo.project(lat: builder.lat, lon: builder.lon, north: 3_000, east: 400)
        builder.samples.append(GeoSample(
            time: builder.time.addingTimeInterval(120),
            latitude: far.lat,
            longitude: far.lon,
            altitude: builder.alt - 10,
            horizontalAccuracy: 5,
            gpsSpeed: 0
        ))
        let tracker = SessionTracker.replay(builder.samples)
        try expect(
            tracker.summary.distance < 400,
            "un trou de 2 min ne doit pas tracer 3 km en ligne droite (\(tracker.summary.distance))"
        )
    }

    static func cleanDescentIsOneRun() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.19, lon: 6.84, alt: 2_000)
        builder.leg(seconds: 40, north: 12, vertical: -2)
        let tracker = SessionTracker.replay(builder.samples)
        let summary = tracker.summary
        try expect(
            tracker.runs.count == 1,
            "une descente propre = 1 run, obtenu \(tracker.runs.count), phase \(tracker.phase), dist \(summary.distance), vert \(summary.vertical)"
        )
        try expect(summary.distance > 320 && summary.distance < 520, "distance \(summary.distance)")
        try expect(summary.vertical > 55 && summary.vertical < 85, "dénivelé \(summary.vertical)")
        try expect(summary.maxSpeed > 11, "vitesse max \(summary.maxSpeed)")
        let run = tracker.runs[0]
        try expect(run.avgSpeed > 8 && run.avgSpeed < 14, "vitesse moyenne \(run.avgSpeed)")
        try expect(run.duration > 25 && run.duration <= 40, "durée \(run.duration)")
    }

    static func descentLiftDescentIsTwoRuns() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.19, lon: 6.84, alt: 2_000)
        builder.leg(seconds: 35, north: 12, vertical: -2.1)
        builder.leg(seconds: 18, north: 0, vertical: 0, gpsSpeed: 0)
        builder.leg(seconds: 30, north: -4, vertical: 1.6, gpsSpeed: 4)
        builder.leg(seconds: 16, north: 0, vertical: 0, gpsSpeed: 0)
        builder.leg(seconds: 32, north: 11, east: 2, vertical: -1.8)
        let tracker = SessionTracker.replay(builder.samples)
        try expect(
            tracker.runs.count == 2,
            "deux descentes séparées par une remontée, obtenu \(tracker.runs.count) (phase \(tracker.phase), vert \(tracker.summary.vertical))"
        )
        try expect(tracker.runs[0].maxSpeed > 10, "max run 1")
        try expect(tracker.runs[1].maxSpeed > 9, "max run 2")
        try expect(tracker.summary.vertical > 70, "le dénivelé des deux runs s'additionne (\(tracker.summary.vertical))")
    }

    static func liftAloneIsNotARun() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.8, alt: 1_400)
        builder.leg(seconds: 50, north: 4, vertical: 1.5, gpsSpeed: 4.2)
        let tracker = SessionTracker.replay(builder.samples)
        try expect(tracker.runs.isEmpty, "une remontée n'est pas une descente (\(tracker.runs.count))")
        try expect(tracker.phase == .lift, "phase finale \(tracker.phase)")
    }

    static func shortBurstIsNotAQualifiedRun() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.8, alt: 1_500)
        builder.leg(seconds: 6, north: 8, vertical: -1)
        let tracker = SessionTracker.replay(builder.samples)
        try expect(tracker.runs.isEmpty, "6 s ne font pas une descente comptée")
    }

    static func stationaryIsRest() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.2, lon: 6.8, alt: 1_200)
        builder.leg(seconds: 25, north: 0, vertical: 0, gpsSpeed: 0)
        let tracker = SessionTracker.replay(builder.samples)
        try expect(tracker.phase == .rest, "phase \(tracker.phase)")
        try expect(tracker.runs.isEmpty, "pas de descente à l'arrêt")
        try expect(tracker.summary.distance < 5, "distance \(tracker.summary.distance)")
    }

    static func replayMatchesIncremental() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.18, lon: 6.86, alt: 1_750)
        builder.leg(seconds: 30, north: 13, vertical: -2)
        builder.leg(seconds: 12, north: 0, vertical: 0, gpsSpeed: 0)
        var incremental = SessionTracker()
        for sample in builder.samples {
            _ = incremental.ingest(sample)
        }
        let replayed = SessionTracker.replay(builder.samples)
        try expect(incremental.runs.count == replayed.runs.count, "nombre de runs")
        try expectClose(incremental.summary.distance, replayed.summary.distance, tol: 0.01, "distance")
        try expectClose(incremental.summary.vertical, replayed.summary.vertical, tol: 0.01, "dénivelé")
        try expect(incremental.samples.count == replayed.samples.count, "points gardés")
    }

    static func noisyDescentStillOneRun() throws {
        var rng = LCG(state: 7)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var samples: [GeoSample] = []
        var lat = 46.19
        var lon = 6.84
        var alt = 1_900.0
        for index in 0...45 {
            let northNoise = (rng.unit() - 0.5) * 3
            let eastNoise = (rng.unit() - 0.5) * 3
            let moved = Geo.project(lat: lat, lon: lon, north: 12 + northNoise, east: eastNoise)
            lat = moved.lat
            lon = moved.lon
            alt += -2 + (rng.unit() - 0.5) * 1.2
            samples.append(GeoSample(
                time: start.addingTimeInterval(Double(index)),
                latitude: lat,
                longitude: lon,
                altitude: alt,
                horizontalAccuracy: 6,
                gpsSpeed: 12
            ))
        }
        let tracker = SessionTracker.replay(samples)
        try expect(
            tracker.runs.count == 1,
            "descente bruitée = 1 run, obtenu \(tracker.runs.count) dist \(tracker.summary.distance) vert \(tracker.summary.vertical)"
        )
        try expect(tracker.summary.distance > 300, "distance \(tracker.summary.distance)")
        try expect(tracker.summary.vertical > 40, "dénivelé \(tracker.summary.vertical)")
    }

    static func airtimeCountsArmedJump() throws {
        var detector = AirtimeDetector()
        var hit: AirtimeHit?
        for step in 0...20 {
            let time = Double(step) * 0.05
            let g = (time >= 0.2 && time < 0.62) ? 0.15 : 1.0
            if let event = detector.ingest(time: time, magnitudeG: g, armed: true) {
                hit = event
            }
        }
        guard let hit else { throw Check(message: "un saut d'environ 0,4 s doit être détecté") }
        try expect(hit.duration > 0.3 && hit.duration < 0.55, "durée \(hit.duration)")
    }

    static func airtimeIgnoresTinyAndLongAndUnarmed() throws {
        var tiny = AirtimeDetector()
        var tinyHit: AirtimeHit?
        for step in 0...10 {
            let time = Double(step) * 0.02
            let g = (time >= 0.04 && time < 0.08) ? 0.1 : 1.0
            tinyHit = tiny.ingest(time: time, magnitudeG: g, armed: true) ?? tinyHit
        }
        try expect(tinyHit == nil, "un à-coup de 0,04 s n'est pas un saut")

        var long = AirtimeDetector()
        var longHit: AirtimeHit?
        for step in 0...100 {
            let time = Double(step) * 0.05
            let g = time < 4.2 ? 0.1 : 1.0
            longHit = long.ingest(time: time, magnitudeG: g, armed: true) ?? longHit
        }
        try expect(longHit == nil, "4 s en l'air, c'est un trou de capteur, pas un saut")

        var disarmed = AirtimeDetector()
        var disarmedHit: AirtimeHit?
        for step in 0...20 {
            let time = Double(step) * 0.05
            let g = (time >= 0.2 && time < 0.7) ? 0.1 : 1.0
            disarmedHit = disarmed.ingest(time: time, magnitudeG: g, armed: false) ?? disarmedHit
        }
        try expect(disarmedHit == nil, "sans vitesse, on ne compte pas l'airtime")
    }

    static func gpxRoundTripCoordinates() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var builder = TraceBuilder(time: start, lat: 46.204, lon: 6.143, alt: 1_200)
        builder.leg(seconds: 25, north: 11, east: -2, vertical: -1.6)
        let tracker = SessionTracker.replay(builder.samples)
        let archive = SessionArchive(
            version: 1,
            id: UUID(),
            startedAt: start,
            endedAt: builder.time,
            resort: "Salève & Genève",
            riderName: "Sam",
            isComplete: true,
            isSample: false,
            raw: tracker.raw,
            samples: tracker.samples,
            runs: tracker.runs,
            jumps: [],
            maxSpeed: tracker.summary.maxSpeed,
            distance: tracker.summary.distance,
            vertical: tracker.summary.vertical,
            duration: 25
        )
        let xml = GPXCodec.encode(archive: archive)
        try expect(xml.contains("Salève"), "le nom doit être échappé et présent")
        try expect(xml.contains("&amp;"), "le & doit être échappé")
        let parsed = try GPXCodec.parse(xml, missingTimeStart: start)
        try expect(parsed.count == tracker.samples.count, "autant de points qu'exportés")
        try expectClose(parsed[0].latitude, tracker.samples[0].latitude, tol: 0.000001, "latitude")
        try expectClose(parsed[0].longitude, tracker.samples[0].longitude, tol: 0.000001, "longitude")
        let again = SessionTracker.replay(parsed)
        try expect(again.runs.count == tracker.runs.count, "la trace réimportée redonne les descentes")
    }

    static func sessionFileRoundTrip() throws {
        let archive = SampleDay.make(on: Date(timeIntervalSince1970: 1_763_000_000))
        let data = try SessionFile.encode(archive)
        let decoded = try SessionFile.decode(data)
        try expect(decoded.runs.count == archive.runs.count, "runs")
        try expect(decoded.jumps.count == archive.jumps.count, "sauts")
        try expectClose(decoded.distance, archive.distance, tol: 0.01, "distance")
        try expect(decoded.resort == archive.resort, "station")
        try expect(decoded.samples.count == archive.samples.count, "points")
    }

    static func seasonBoundaries() throws {
        let calendar = Calendar.zurich
        let november = try date(2026, 11, 25, calendar)
        let march = try date(2026, 3, 2, calendar)
        let opening = try date(2026, 9, 1, calendar)
        let eve = try date(2026, 8, 31, calendar)
        try expect(Season.containing(november).title == "Saison 2026–2027", Season.containing(november).title)
        try expect(Season.containing(march).title == "Saison 2025–2026", Season.containing(march).title)
        try expect(Season.containing(opening).title == "Saison 2026–2027", Season.containing(opening).title)
        try expect(Season.containing(eve).title == "Saison 2025–2026", Season.containing(eve).title)
        try expect(Season.containing(november).contains(november), "la date est dans sa saison")
    }

    static func speedBands() throws {
        try expect(SpeedBand.forSpeed(10 / 3.6) == .slow, "10 km/h")
        try expect(SpeedBand.forSpeed(35 / 3.6) == .cruise, "35 km/h")
        try expect(SpeedBand.forSpeed(50 / 3.6) == .fast, "50 km/h")
        try expect(SpeedBand.forSpeed(70 / 3.6) == .flying, "70 km/h")
        try expect(SpeedBand.forSpeed(90 / 3.6) == .extreme, "90 km/h")
    }

    static func durationAndDecimalFormat() throws {
        try expect(FormatFR.duration(0) == "0:00", FormatFR.duration(0))
        try expect(FormatFR.duration(65) == "1:05", FormatFR.duration(65))
        try expect(FormatFR.duration(3_661) == "1:01:01", FormatFR.duration(3_661))
        try expect(FormatFR.decimal(1234.56, fractionDigits: 1) == "1\u{202F}234,6", FormatFR.decimal(1234.56, fractionDigits: 1))
        try expect(FormatFR.speedUnit(.metric) == "km/h", "unité")
        try expect(FormatFR.speed(10, prefs: .metric) == "36,0", FormatFR.speed(10, prefs: .metric))
        try expect(FormatFR.distance(840, prefs: .metric) == "840 m", FormatFR.distance(840, prefs: .metric))
        try expect(FormatFR.distance(4_200, prefs: .metric) == "4,2 km", FormatFR.distance(4_200, prefs: .metric))
    }

    static func sampleDayHasSeveralRuns() throws {
        let archive = SampleDay.make(on: Date(timeIntervalSince1970: 1_763_000_000))
        try expect(archive.isSample, "exemple")
        try expect(archive.runs.count >= 4, "runs d'exemple \(archive.runs.count)")
        try expect(archive.distance > 1_000, "distance \(archive.distance)")
        try expect(archive.vertical > 200, "dénivelé \(archive.vertical)")
        try expect(archive.maxSpeed > 12, "vitesse \(archive.maxSpeed)")
        try expect(archive.jumps.count == 4, "sauts")
        try expect(!archive.samples.isEmpty, "trace")
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) throws -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 12
        guard let date = calendar.date(from: parts) else {
            throw Check(message: "date invalide")
        }
        return date
    }
}
