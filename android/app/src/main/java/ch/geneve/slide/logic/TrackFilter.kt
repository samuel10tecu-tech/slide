package ch.geneve.slide.logic

/** Cleans the GPS stream: accuracy, micro-noise and impossible position jumps. Port of the iOS TrackFilter. */
class TrackFilter(private val config: DetectorConfig = DetectorConfig()) {
    sealed class Result {
        data class Accepted(val sample: TrackSample) : Result()
        data class Rejected(val reason: RejectReason) : Result()
    }

    private var anchor: GeoSample? = null
    private var smoothSpeed = 0.0
    private var smoothAltitude = 0.0
    private var spikeStreak = 0
    private var lastSpike: GeoSample? = null

    fun push(sample: GeoSample): Result {
        if (!sample.latitude.isFinite() || !sample.longitude.isFinite() ||
            !sample.altitude.isFinite() || !sample.horizontalAccuracy.isFinite()
        ) return Result.Rejected(RejectReason.NON_FINITE)
        if (sample.horizontalAccuracy < 0 || sample.horizontalAccuracy > config.maxHorizontalAccuracy) {
            return Result.Rejected(RejectReason.BAD_ACCURACY)
        }

        val anchor = this.anchor
        if (anchor == null) {
            this.anchor = sample
            smoothAltitude = sample.altitude
            smoothSpeed = positiveSpeed(sample.gpsSpeed)
            return Result.Accepted(make(sample, 0.0))
        }

        val dt = sample.time - anchor.time
        if (dt < 0) return Result.Rejected(RejectReason.TIME_WENT_BACKWARDS)
        if (dt < config.minDt) return Result.Rejected(RejectReason.TOO_SOON)

        val distance = Geo.haversineMeters(anchor.latitude, anchor.longitude, sample.latitude, sample.longitude)
        val computed = distance / dt

        if (dt > config.maxGap) return Result.Accepted(relocate(sample, positiveSpeed(sample.gpsSpeed)))
        if (computed > config.maxSpeed) return rejectOrRelocateSpike(sample)

        spikeStreak = 0
        lastSpike = null

        val gps = sample.gpsSpeed?.takeIf { it.isFinite() && it >= 0 }
        val confident = gps ?: computed
        val noiseFloor = maxOf(config.stationarySlack, sample.horizontalAccuracy * config.accuracyNoiseFactor)
        var used = distance
        if (distance < noiseFloor && confident < config.restSpeed) used = 0.0
        if (sample.horizontalAccuracy >= 10 && (gps ?: 0.0) < config.skiSpeed &&
            distance < sample.horizontalAccuracy * 0.85
        ) used = 0.0

        val instant = if (used == 0.0 && (gps ?: 0.0) < config.skiSpeed) {
            minOf(gps ?: 0.0, config.maxSpeed)
        } else {
            minOf(maxOf(gps ?: computed, 0.0), config.maxSpeed)
        }

        smoothSpeed = config.speedAlpha * instant + (1 - config.speedAlpha) * smoothSpeed
        smoothAltitude = config.altitudeAlpha * sample.altitude + (1 - config.altitudeAlpha) * smoothAltitude
        this.anchor = sample
        return Result.Accepted(make(sample, used))
    }

    private fun rejectOrRelocateSpike(sample: GeoSample): Result {
        val previous = lastSpike
        if (previous != null) {
            val dt = sample.time - previous.time
            if (dt >= config.minDt) {
                val step = Geo.haversineMeters(previous.latitude, previous.longitude, sample.latitude, sample.longitude)
                spikeStreak = if (step / dt <= config.maxSpeed) spikeStreak + 1 else 1
            }
        } else {
            spikeStreak = 1
        }
        lastSpike = sample
        if (spikeStreak >= config.spikeResetCount) {
            val hint = positiveSpeed(sample.gpsSpeed)
            return Result.Accepted(relocate(sample, minOf(hint, config.maxSpeed)))
        }
        return Result.Rejected(RejectReason.SPEED_SPIKE)
    }

    private fun relocate(sample: GeoSample, speedHint: Double): TrackSample {
        anchor = sample
        spikeStreak = 0
        lastSpike = null
        smoothSpeed = config.speedAlpha * speedHint + (1 - config.speedAlpha) * smoothSpeed
        smoothAltitude = config.altitudeAlpha * sample.altitude + (1 - config.altitudeAlpha) * smoothAltitude
        return make(sample, 0.0)
    }

    private fun make(sample: GeoSample, segment: Double) = TrackSample(
        time = sample.time,
        latitude = sample.latitude,
        longitude = sample.longitude,
        altitude = smoothAltitude,
        rawAltitude = sample.altitude,
        speed = maxOf(0.0, smoothSpeed),
        accuracy = sample.horizontalAccuracy,
        segmentDistance = maxOf(0.0, segment),
    )

    private fun positiveSpeed(value: Double?): Double {
        if (value == null || !value.isFinite() || value < 0) return 0.0
        return minOf(value, config.maxSpeed)
    }
}
