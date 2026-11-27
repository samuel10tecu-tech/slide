package ch.geneve.slide.logic

import java.util.Locale

class GpxException(message: String) : Exception(message)

/** GPX export and import, same output as the iOS GPXCodec (speed and phase in <extensions>). */
object GpxCodec {
    fun encode(archive: SessionArchive): String {
        val name = escape(archive.resort.ifEmpty { "Slide" })
        val out = StringBuilder(512 + archive.samples.size * 220)
        out.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        out.append("<gpx version=\"1.1\" creator=\"Slide\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n")
        out.append("  <metadata>\n    <name>").append(name).append("</name>\n")
        out.append("    <time>").append(SessionFile.date(archive.startedAt)).append("</time>\n  </metadata>\n")
        out.append("  <trk>\n    <name>").append(name).append("</name>\n    <trkseg>\n")
        for (sample in archive.samples) {
            out.append("      <trkpt lat=\"").append(format(sample.latitude))
                .append("\" lon=\"").append(format(sample.longitude)).append("\">\n")
                .append("        <ele>").append(format(sample.rawAltitude)).append("</ele>\n")
                .append("        <time>").append(SessionFile.date(sample.time)).append("</time>\n")
                .append("        <extensions>\n")
                .append("          <speed>").append(format(sample.speed)).append("</speed>\n")
                .append("          <phase>").append(sample.phase.raw).append("</phase>\n")
                .append("        </extensions>\n      </trkpt>\n")
        }
        out.append("    </trkseg>\n  </trk>\n</gpx>")
        return out.toString()
    }

    private val point = Regex("<trkpt\\b([^>]*)>(.*?)</trkpt>", setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE))

    fun parse(xml: String, missingTimeStart: Double = System.currentTimeMillis() / 1000.0): List<GeoSample> {
        if (!xml.contains("trkpt")) throw GpxException("empty")
        val samples = mutableListOf<GeoSample>()
        var missingIndex = 0
        for (match in point.findAll(xml)) {
            val attrs = match.groupValues[1]
            val body = match.groupValues[2]
            val lat = attribute("lat", attrs) ?: continue
            val lon = attribute("lon", attrs) ?: continue
            val ele = firstText("ele", body)?.toDoubleOrNull() ?: 0.0
            val speed = firstText("speed", body)?.toDoubleOrNull()
            val time = firstText("time", body)?.let { runCatching { SessionFile.parseDate(it) }.getOrNull() }
                ?: (missingTimeStart + missingIndex++)
            samples.add(
                GeoSample(
                    time = time,
                    latitude = lat,
                    longitude = lon,
                    altitude = ele,
                    horizontalAccuracy = 5.0,
                    gpsSpeed = speed?.takeIf { it.isFinite() && it >= 0 && it < 80 },
                ),
            )
        }
        if (samples.isEmpty()) throw GpxException("empty")
        return samples
    }

    private fun attribute(name: String, text: String): Double? =
        Regex("$name\\s*=\\s*[\"']([+-]?[0-9]*\\.?[0-9]+)[\"']", RegexOption.IGNORE_CASE)
            .find(text)?.groupValues?.get(1)?.toDoubleOrNull()

    private fun firstText(tag: String, body: String): String? =
        Regex("<(?:\\w+:)?$tag\\b[^>]*>(.*?)</(?:\\w+:)?$tag>", setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE))
            .find(body)?.groupValues?.get(1)?.trim()

    private fun format(value: Double) = String.format(Locale.US, "%.6f", value)

    private fun escape(text: String) = text
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
}
