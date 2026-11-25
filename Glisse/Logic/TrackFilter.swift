import Foundation

/// Nettoie le flux GPS : précision, micro-bruit, et sauts de position impossibles.
struct TrackFilter {
    var config: DetectorConfig
    private var anchor: GeoSample?
    private var smoothSpeed = 0.0
    private var smoothAltitude = 0.0
    private var spikeStreak = 0
    private var lastSpike: GeoSample?

    init(config: DetectorConfig = DetectorConfig()) {
        self.config = config
    }

    mutating func push(_ sample: GeoSample) -> Result<TrackSample, RejectReason> {
        guard sample.latitude.isFinite,
              sample.longitude.isFinite,
              sample.altitude.isFinite,
              sample.horizontalAccuracy.isFinite
        else {
            return .failure(.nonFinite)
        }
        guard sample.horizontalAccuracy >= 0,
              sample.horizontalAccuracy <= config.maxHorizontalAccuracy
        else {
            return .failure(.badAccuracy)
        }

        guard let anchor else {
            self.anchor = sample
            smoothAltitude = sample.altitude
            smoothSpeed = positiveSpeed(sample.gpsSpeed)
            return .success(make(sample, segment: 0))
        }

        let dt = sample.time.timeIntervalSince(anchor.time)
        if dt < 0 {
            return .failure(.timeWentBackwards)
        }
        if dt < config.minDt {
            return .failure(.tooSoon)
        }

        let distance = Geo.haversineMeters(
            lat1: anchor.latitude,
            lon1: anchor.longitude,
            lat2: sample.latitude,
            lon2: sample.longitude
        )
        let computed = distance / dt

        if dt > config.maxGap {
            return .success(relocate(sample, speedHint: positiveSpeed(sample.gpsSpeed)))
        }

        if computed > config.maxSpeed {
            return rejectOrRelocateSpike(sample)
        }

        spikeStreak = 0
        lastSpike = nil

        let gps = sample.gpsSpeed.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let confident = gps ?? computed
        let noiseFloor = max(config.stationarySlack, sample.horizontalAccuracy * config.accuracyNoiseFactor)
        var used = distance
        if distance < noiseFloor && confident < config.restSpeed {
            used = 0
        }
        if sample.horizontalAccuracy >= 10,
           (gps ?? 0) < config.skiSpeed,
           distance < sample.horizontalAccuracy * 0.85
        {
            used = 0
        }

        let instant: Double
        if used == 0 && (gps ?? 0) < config.skiSpeed {
            instant = min(gps ?? 0, config.maxSpeed)
        } else {
            instant = min(max(gps ?? computed, 0), config.maxSpeed)
        }

        smoothSpeed = config.speedAlpha * instant + (1 - config.speedAlpha) * smoothSpeed
        smoothAltitude = config.altitudeAlpha * sample.altitude + (1 - config.altitudeAlpha) * smoothAltitude
        self.anchor = sample
        return .success(make(sample, segment: used))
    }

    private mutating func rejectOrRelocateSpike(_ sample: GeoSample) -> Result<TrackSample, RejectReason> {
        if let lastSpike {
            let dt = sample.time.timeIntervalSince(lastSpike.time)
            if dt >= config.minDt {
                let step = Geo.haversineMeters(
                    lat1: lastSpike.latitude,
                    lon1: lastSpike.longitude,
                    lat2: sample.latitude,
                    lon2: sample.longitude
                )
                if step / dt <= config.maxSpeed {
                    spikeStreak += 1
                } else {
                    spikeStreak = 1
                }
            }
        } else {
            spikeStreak = 1
        }
        lastSpike = sample
        if spikeStreak >= config.spikeResetCount {
            let hint = positiveSpeed(sample.gpsSpeed)
            return .success(relocate(sample, speedHint: min(hint, config.maxSpeed)))
        }
        return .failure(.speedSpike)
    }

    private mutating func relocate(_ sample: GeoSample, speedHint: Double) -> TrackSample {
        anchor = sample
        spikeStreak = 0
        lastSpike = nil
        smoothSpeed = config.speedAlpha * speedHint + (1 - config.speedAlpha) * smoothSpeed
        smoothAltitude = config.altitudeAlpha * sample.altitude + (1 - config.altitudeAlpha) * smoothAltitude
        return make(sample, segment: 0)
    }

    private func make(_ sample: GeoSample, segment: Double) -> TrackSample {
        TrackSample(
            time: sample.time,
            latitude: sample.latitude,
            longitude: sample.longitude,
            altitude: smoothAltitude,
            rawAltitude: sample.altitude,
            speed: max(0, smoothSpeed),
            accuracy: sample.horizontalAccuracy,
            segmentDistance: max(0, segment)
        )
    }

    private func positiveSpeed(_ value: Double?) -> Double {
        guard let value, value.isFinite, value >= 0 else { return 0 }
        return min(value, config.maxSpeed)
    }
}
