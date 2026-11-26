import Foundation

enum SampleDay {
    /// Une journée fictive, générée par le même détecteur que le suivi réel.
    static func make(on day: Date = Date(), resort: String = "Les Crosets") -> SessionArchive {
        let calendar = Calendar.slide
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 9
        parts.minute = 40
        parts.second = 0
        let start = calendar.date(from: parts) ?? day

        var samples: [GeoSample] = []
        var cursor = start
        var lat = 46.1862
        var lon = 6.8428
        var alt = 1_920.0

        func append(seconds: Int, north: Double, east: Double, vertical: Double, speed: Double, accuracy: Double = 4) {
            for index in 0...seconds {
                let time = cursor.addingTimeInterval(Double(index))
                let wobble = sin(Double(index) / 5.5) * east
                let moved = Geo.project(lat: lat, lon: lon, north: north * Double(index), east: wobble + east * 0.15 * Double(index))
                samples.append(GeoSample(
                    time: time,
                    latitude: moved.lat,
                    longitude: moved.lon,
                    altitude: alt + vertical * Double(index),
                    horizontalAccuracy: accuracy,
                    gpsSpeed: speed
                ))
            }
            if let last = samples.last {
                lat = last.latitude
                lon = last.longitude
                alt = last.altitude
                cursor = last.time.addingTimeInterval(1)
            }
        }

        let runs: [(Int, Double, Double, Double)] = [
            (48, 10.5, -1.7, 2.2),
            (64, 13.0, -2.3, -1.4),
            (36, 16.5, -3.1, 2.8),
            (72, 12.0, -2.0, -2.0),
            (50, 14.0, -2.4, 1.2),
        ]
        for (offset, plan) in runs.enumerated() {
            append(seconds: plan.0, north: plan.1, east: plan.3, vertical: plan.2, speed: plan.1)
            append(seconds: 14, north: 0, east: 0, vertical: 0, speed: 0)
            if offset < runs.count - 1 {
                let climb = min(abs(plan.2) * Double(plan.0) * 0.72, 160)
                let liftSeconds = 36
                let liftVert = climb / Double(liftSeconds)
                append(seconds: liftSeconds, north: -3.6, east: -plan.3 * 0.3, vertical: liftVert, speed: 3.8)
                append(seconds: 10, north: 0, east: 0, vertical: 0, speed: 0)
            }
        }

        let tracker = SessionTracker.replay(samples)
        let ended = samples.last?.time ?? start
        let jumps = [
            JumpRecord(time: start.addingTimeInterval(80), duration: 0.42),
            JumpRecord(time: start.addingTimeInterval(210), duration: 0.67),
            JumpRecord(time: start.addingTimeInterval(430), duration: 0.38),
            JumpRecord(time: start.addingTimeInterval(690), duration: 0.81),
        ]
        let summary = tracker.summary
        return SessionArchive(
            version: SessionArchive.currentVersion,
            id: UUID(),
            startedAt: start,
            endedAt: ended,
            resort: resort,
            riderName: "",
            isComplete: true,
            isSample: true,
            raw: tracker.raw,
            samples: tracker.samples,
            runs: tracker.runs,
            jumps: jumps,
            maxSpeed: summary.maxSpeed,
            distance: summary.distance,
            vertical: summary.vertical,
            duration: ended.timeIntervalSince(start)
        )
    }
}
