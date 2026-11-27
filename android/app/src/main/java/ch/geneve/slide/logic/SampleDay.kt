package ch.geneve.slide.logic

import java.time.Instant
import java.time.ZoneId
import kotlin.math.abs
import kotlin.math.sin

/** A made-up day at Les Crosets, run through the same detector as real tracking. Port of the iOS SampleDay. */
object SampleDay {
    fun make(onDay: Double = System.currentTimeMillis() / 1000.0, resort: String = "Les Crosets"): SessionArchive {
        val zone = ZoneId.systemDefault()
        val start = Instant.ofEpochMilli((onDay * 1000).toLong()).atZone(zone).toLocalDate()
            .atTime(9, 40).atZone(zone).toEpochSecond().toDouble()

        val samples = mutableListOf<GeoSample>()
        var cursor = start
        var lat = 46.1862
        var lon = 6.8428
        var alt = 1_920.0

        fun append(seconds: Int, north: Double, east: Double, vertical: Double, speed: Double) {
            for (index in 0..seconds) {
                val wobble = sin(index / 5.5) * east
                val (mLat, mLon) = Geo.project(lat, lon, north * index, wobble + east * 0.15 * index)
                samples.add(GeoSample(cursor + index, mLat, mLon, alt + vertical * index, 4.0, speed))
            }
            val last = samples.last()
            lat = last.latitude
            lon = last.longitude
            alt = last.altitude
            cursor = last.time + 1
        }

        val runs = listOf(
            listOf(48.0, 10.5, -1.7, 2.2),
            listOf(64.0, 13.0, -2.3, -1.4),
            listOf(36.0, 16.5, -3.1, 2.8),
            listOf(72.0, 12.0, -2.0, -2.0),
            listOf(50.0, 14.0, -2.4, 1.2),
        )
        runs.forEachIndexed { offset, plan ->
            val seconds = plan[0].toInt()
            append(seconds, north = plan[1], east = plan[3], vertical = plan[2], speed = plan[1])
            append(14, 0.0, 0.0, 0.0, 0.0)
            if (offset < runs.size - 1) {
                val climb = minOf(abs(plan[2]) * seconds * 0.72, 160.0)
                val liftSeconds = 36
                append(liftSeconds, north = -3.6, east = -plan[3] * 0.3, vertical = climb / liftSeconds, speed = 3.8)
                append(10, 0.0, 0.0, 0.0, 0.0)
            }
        }

        val tracker = SessionTracker.replay(samples)
        val ended = samples.lastOrNull()?.time ?: start
        val summary = tracker.summary
        return SessionArchive(
            id = newId(),
            startedAt = start,
            endedAt = ended,
            resort = resort,
            riderName = "",
            isComplete = true,
            isSample = true,
            raw = tracker.raw.toList(),
            samples = tracker.samples,
            runs = tracker.runs,
            jumps = listOf(
                JumpRecord(time = start + 80, duration = 0.42),
                JumpRecord(time = start + 210, duration = 0.67),
                JumpRecord(time = start + 430, duration = 0.38),
                JumpRecord(time = start + 690, duration = 0.81),
            ),
            maxSpeed = summary.maxSpeed,
            distance = summary.distance,
            vertical = summary.vertical,
            duration = ended - start,
        )
    }
}
