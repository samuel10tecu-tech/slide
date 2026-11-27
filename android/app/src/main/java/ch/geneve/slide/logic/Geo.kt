package ch.geneve.slide.logic

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

object Geo {
    const val EARTH_RADIUS = 6_371_000.0

    fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val p1 = Math.toRadians(lat1)
        val p2 = Math.toRadians(lat2)
        val dP = Math.toRadians(lat2 - lat1)
        val dL = Math.toRadians(lon2 - lon1)
        val a = sin(dP / 2) * sin(dP / 2) + cos(p1) * cos(p2) * sin(dL / 2) * sin(dL / 2)
        return EARTH_RADIUS * 2 * atan2(sqrt(a), sqrt(max(0.0, 1 - a)))
    }

    /** Moves a point by metres to the north and east. */
    fun project(lat: Double, lon: Double, north: Double, east: Double): Pair<Double, Double> {
        val dLat = Math.toDegrees(north / EARTH_RADIUS)
        val cosLat = cos(Math.toRadians(lat))
        val dLon = Math.toDegrees(east / (EARTH_RADIUS * max(cosLat, 0.2)))
        return (lat + dLat) to (lon + dLon)
    }
}

/** Alpine season: 1 September to 31 August, in the phone's time zone. */
data class Season(val start: Double, val end: Double, val title: String) {
    operator fun contains(time: Double): Boolean = time >= start && time < end

    companion object {
        fun containing(time: Double, zone: ZoneId = ZoneId.systemDefault()): Season {
            val date = Instant.ofEpochMilli((time * 1000).toLong()).atZone(zone).toLocalDate()
            val startYear = if (date.monthValue >= 9) date.year else date.year - 1
            val start = LocalDate.of(startYear, 9, 1).atStartOfDay(zone).toEpochSecond().toDouble()
            val end = LocalDate.of(startYear + 1, 9, 1).atStartOfDay(zone).toEpochSecond().toDouble()
            return Season(start, end, "$startYear–${startYear + 1}")
        }
    }
}

enum class SpeedBand {
    SLOW, CRUISE, FAST, FLYING, EXTREME;

    companion object {
        fun forSpeed(metersPerSecond: Double): SpeedBand {
            val kmh = metersPerSecond * 3.6
            return when {
                kmh < 20 -> SLOW
                kmh < 40 -> CRUISE
                kmh < 60 -> FAST
                kmh < 80 -> FLYING
                else -> EXTREME
            }
        }
    }
}

/** Display colours for a ski speed. Absolute km/h stops, or stretched so the day's max sits near the top. */
object SpeedPaint {
    val stops: List<Pair<Double, Int>> = listOf(
        0.0 to 0x3B82F6,
        15.0 to 0x14C8C0,
        30.0 to 0x3DDC6A,
        45.0 to 0xFFE14A,
        60.0 to 0xFF9A2E,
        75.0 to 0xFF3B4E,
        90.0 to 0xE23BFF,
    )

    fun paintedKmh(metersPerSecond: Double, dayMaxKmh: Double?): Double {
        val raw = max(0.0, metersPerSecond * 3.6)
        if (dayMaxKmh == null || dayMaxKmh <= 20) return raw
        return min(100.0, raw / dayMaxKmh * 90)
    }

    /** Opaque ARGB colour. */
    fun argb(metersPerSecond: Double, dayMaxKmh: Double? = null): Int {
        val kmh = paintedKmh(metersPerSecond, dayMaxKmh)
        val upper = stops.indexOfLast { it.first <= kmh }.coerceAtLeast(0)
        val next = min(upper + 1, stops.size - 1)
        val a = stops[upper]
        val b = stops[next]
        val span = max(0.001, b.first - a.first)
        val t = if (upper == next) 0.0 else min(1.0, max(0.0, (kmh - a.first) / span))
        fun channel(shift: Int): Int {
            val ca = (a.second shr shift) and 0xFF
            val cb = (b.second shr shift) and 0xFF
            return (ca + (cb - ca) * t).toInt().coerceIn(0, 255)
        }
        return (0xFF shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
    }
}
