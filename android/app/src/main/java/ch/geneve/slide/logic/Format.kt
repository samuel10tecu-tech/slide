package ch.geneve.slide.logic

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

data class UnitPrefs(
    val speedMetric: Boolean = true,
    val distanceMetric: Boolean = true,
    val altitudeMetric: Boolean = true,
) {
    companion object {
        val METRIC = UnitPrefs()
    }
}

object Units {
    fun kmh(mps: Double) = mps * 3.6
    fun mph(mps: Double) = mps * 2.2369362920544
    fun feet(meters: Double) = meters * 3.2808398950131
    fun miles(meters: Double) = meters / 1_609.344
    fun kilometers(meters: Double) = meters / 1_000
}

/** Number and date formatting shared with iOS (FormatFR). `french` means comma decimals and a narrow space for thousands. */
object Fmt {
    fun decimal(value: Double, fractionDigits: Int, grouping: Boolean = true, french: Boolean = true): String {
        val digits = fractionDigits.coerceIn(0, 6)
        if (!value.isFinite()) return "—"
        val rounded = BigDecimal.valueOf(value).setScale(digits, RoundingMode.HALF_UP)
        val negative = rounded.signum() < 0
        val plain = rounded.abs().toPlainString()
        val parts = plain.split(".")
        val whole = if (grouping) group(parts[0], if (french) ' ' else ',') else parts[0]
        val body = if (digits == 0) whole else whole + (if (french) "," else ".") + parts.getOrElse(1) { "" }.padEnd(digits, '0')
        return if (negative && body.any { it in '1'..'9' }) "-$body" else body
    }

    fun duration(seconds: Double): String {
        val total = maxOf(0, seconds.toLong())
        val hours = total / 3600
        val minutes = (total % 3600) / 60
        val secs = total % 60
        return if (hours > 0) "$hours:${two(minutes)}:${two(secs)}" else "$minutes:${two(secs)}"
    }

    fun speed(mps: Double, prefs: UnitPrefs, french: Boolean): String =
        decimal(if (prefs.speedMetric) Units.kmh(mps) else Units.mph(mps), 1, french = french)

    fun speedUnit(prefs: UnitPrefs) = if (prefs.speedMetric) "km/h" else "mph"

    fun distance(meters: Double, prefs: UnitPrefs, french: Boolean): String {
        if (prefs.distanceMetric) {
            if (meters < 1_000) return decimal(meters, 0, french = french) + " m"
            return decimal(Units.kilometers(meters), 1, french = french) + " km"
        }
        val miles = Units.miles(meters)
        if (miles < 0.1) return decimal(Units.feet(meters), 0, french = french) + " ft"
        return decimal(miles, 2, french = french) + " mi"
    }

    fun altitude(meters: Double, prefs: UnitPrefs, french: Boolean): String =
        if (prefs.altitudeMetric) decimal(meters, 0, french = french) + " m"
        else decimal(Units.feet(meters), 0, french = french) + " ft"

    fun dayTitle(time: Double, locale: Locale) = dated(time, "EEEE d MMMM", locale).replaceFirstChar { it.titlecase(locale) }
    fun dayShort(time: Double, locale: Locale) = dated(time, "EEE d MMM", locale)
    fun clock(time: Double) = dated(time, "HH:mm", Locale.ROOT)
    fun fileStamp(time: Double) = dated(time, "yyyy-MM-dd-HHmm", Locale.ROOT)

    private fun dated(time: Double, pattern: String, locale: Locale): String =
        DateTimeFormatter.ofPattern(pattern, locale)
            .format(Instant.ofEpochMilli((time * 1000).toLong()).atZone(ZoneId.systemDefault()))

    private fun two(value: Long) = if (value < 10) "0$value" else "$value"

    private fun group(digits: String, mark: Char): String {
        val out = StringBuilder()
        digits.reversed().forEachIndexed { offset, char ->
            if (offset > 0 && offset % 3 == 0) out.append(mark)
            out.append(char)
        }
        return out.reverse().toString()
    }
}
