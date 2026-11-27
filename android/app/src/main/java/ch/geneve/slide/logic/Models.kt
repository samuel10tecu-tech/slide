package ch.geneve.slide.logic

import java.util.UUID

/** Detector thresholds, identical to the iOS DetectorConfig. Speeds in m/s, times in seconds. */
data class DetectorConfig(
    val maxHorizontalAccuracy: Double = 30.0,
    /** Above this (198 km/h) a point is a GPS jump, not a skier. */
    val maxSpeed: Double = 55.0,
    val minDt: Double = 0.35,
    /** Above this the line is cut: GPS gap or a pause, not a straight line. */
    val maxGap: Double = 45.0,
    val stationarySlack: Double = 2.0,
    val accuracyNoiseFactor: Double = 0.45,
    val speedAlpha: Double = 0.4,
    val altitudeAlpha: Double = 0.45,
    val restSpeed: Double = 1.15,
    val skiSpeed: Double = 2.6,
    val fastSkiSpeed: Double = 8.0,
    val descentRate: Double = -0.55,
    val liftRate: Double = 0.5,
    val liftMinSpeed: Double = 0.8,
    val liftMaxSpeed: Double = 9.0,
    val trendWindow: Double = 6.0,
    val minTrendSpan: Double = 3.0,
    val hold: Double = 4.0,
    val minRunDuration: Double = 8.0,
    val minRunDistance: Double = 25.0,
    val minRunVertical: Double = 8.0,
    val spikeResetCount: Int = 4,
)

/** One raw GPS fix. [time] is seconds since 1970. */
data class GeoSample(
    val time: Double,
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val horizontalAccuracy: Double,
    val gpsSpeed: Double? = null,
)

enum class RejectReason { NON_FINITE, BAD_ACCURACY, TIME_WENT_BACKWARDS, TOO_SOON, SPEED_SPIKE }

enum class TrackPhase(val raw: String) {
    UNKNOWN("unknown"), SKIING("skiing"), LIFT("lift"), REST("rest");

    companion object {
        fun from(raw: String?): TrackPhase = entries.firstOrNull { it.raw == raw } ?: UNKNOWN
    }
}

data class TrackSample(
    val id: String = newId(),
    val time: Double,
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val rawAltitude: Double,
    val speed: Double,
    val accuracy: Double,
    val segmentDistance: Double,
    val phase: TrackPhase = TrackPhase.UNKNOWN,
)

data class RunRecord(
    val id: String = newId(),
    val index: Int,
    val startedAt: Double,
    val endedAt: Double,
    val maxSpeed: Double,
    val avgSpeed: Double,
    val distance: Double,
    val verticalDrop: Double,
    val duration: Double,
)

data class JumpRecord(
    val id: String = newId(),
    val time: Double,
    val duration: Double,
)

data class LiveSummary(
    val speed: Double = 0.0,
    val altitude: Double = 0.0,
    val hasFix: Boolean = false,
    val phase: TrackPhase = TrackPhase.UNKNOWN,
    val distance: Double = 0.0,
    val vertical: Double = 0.0,
    val maxSpeed: Double = 0.0,
    val qualifiedRuns: Int = 0,
    val openRun: RunRecord? = null,
    val accuracy: Double = -1.0,
)

data class IngestOutcome(
    val accepted: Boolean,
    val reason: RejectReason?,
    val phase: TrackPhase,
    val qualifiedRuns: Int,
)

/** A full recorded day. Same fields and JSON as the iOS .slide file, so days move between phones. */
data class SessionArchive(
    val version: Int = CURRENT_VERSION,
    val id: String,
    val startedAt: Double,
    val endedAt: Double?,
    val resort: String,
    val riderName: String,
    val isComplete: Boolean,
    val isSample: Boolean,
    val raw: List<GeoSample>,
    val samples: List<TrackSample>,
    val runs: List<RunRecord>,
    val jumps: List<JumpRecord>,
    val maxSpeed: Double,
    val distance: Double,
    val vertical: Double,
    val duration: Double,
) {
    val jumpCount: Int get() = jumps.size
    val airtime: Double get() = jumps.sumOf { it.duration }
    val longestRunDistance: Double get() = runs.maxOfOrNull { it.distance } ?: 0.0

    companion object {
        const val CURRENT_VERSION = 1
    }
}

/** iOS writes UUIDs in upper case; both cases are read. */
fun newId(): String = UUID.randomUUID().toString().uppercase()
