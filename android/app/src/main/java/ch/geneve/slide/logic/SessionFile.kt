package ch.geneve.slide.logic

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * The .slide file: the same JSON as the iOS SessionFile (ISO 8601 dates with milliseconds, upper-case UUIDs),
 * so a day exported on one phone opens on the other. Older .glisse files use the same shape.
 */
object SessionFile {
    private val iso = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)

    fun date(seconds: Double): String = iso.format(Instant.ofEpochMilli(Math.round(seconds * 1000)))

    fun parseDate(text: String): Double {
        val instant = runCatching { Instant.parse(text) }.getOrNull()
            ?: OffsetDateTime.parse(text).toInstant()
        return instant.toEpochMilli() / 1000.0
    }

    fun encode(archive: SessionArchive): String {
        val out = StringBuilder(64 + archive.samples.size * 260 + archive.raw.size * 160)
        out.append("{\"distance\":").append(num(archive.distance))
        out.append(",\"duration\":").append(num(archive.duration))
        archive.endedAt?.let { out.append(",\"endedAt\":\"").append(date(it)).append('"') }
        out.append(",\"id\":").append(quote(archive.id))
        out.append(",\"isComplete\":").append(archive.isComplete)
        out.append(",\"isSample\":").append(archive.isSample)
        out.append(",\"jumps\":[")
        archive.jumps.forEachIndexed { i, jump ->
            if (i > 0) out.append(',')
            out.append("{\"duration\":").append(num(jump.duration))
                .append(",\"id\":").append(quote(jump.id))
                .append(",\"time\":\"").append(date(jump.time)).append("\"}")
        }
        out.append("],\"maxSpeed\":").append(num(archive.maxSpeed))
        out.append(",\"raw\":[")
        archive.raw.forEachIndexed { i, s ->
            if (i > 0) out.append(',')
            out.append("{\"altitude\":").append(num(s.altitude))
            s.gpsSpeed?.let { out.append(",\"gpsSpeed\":").append(num(it)) }
            out.append(",\"horizontalAccuracy\":").append(num(s.horizontalAccuracy))
                .append(",\"latitude\":").append(num(s.latitude))
                .append(",\"longitude\":").append(num(s.longitude))
                .append(",\"time\":\"").append(date(s.time)).append("\"}")
        }
        out.append("],\"resort\":").append(quote(archive.resort))
        out.append(",\"riderName\":").append(quote(archive.riderName))
        out.append(",\"runs\":[")
        archive.runs.forEachIndexed { i, r ->
            if (i > 0) out.append(',')
            out.append("{\"avgSpeed\":").append(num(r.avgSpeed))
                .append(",\"distance\":").append(num(r.distance))
                .append(",\"duration\":").append(num(r.duration))
                .append(",\"endedAt\":\"").append(date(r.endedAt)).append('"')
                .append(",\"id\":").append(quote(r.id))
                .append(",\"index\":").append(r.index)
                .append(",\"maxSpeed\":").append(num(r.maxSpeed))
                .append(",\"startedAt\":\"").append(date(r.startedAt)).append('"')
                .append(",\"verticalDrop\":").append(num(r.verticalDrop)).append('}')
        }
        out.append("],\"samples\":[")
        archive.samples.forEachIndexed { i, s ->
            if (i > 0) out.append(',')
            out.append("{\"accuracy\":").append(num(s.accuracy))
                .append(",\"altitude\":").append(num(s.altitude))
                .append(",\"id\":").append(quote(s.id))
                .append(",\"latitude\":").append(num(s.latitude))
                .append(",\"longitude\":").append(num(s.longitude))
                .append(",\"phase\":\"").append(s.phase.raw).append('"')
                .append(",\"rawAltitude\":").append(num(s.rawAltitude))
                .append(",\"segmentDistance\":").append(num(s.segmentDistance))
                .append(",\"speed\":").append(num(s.speed))
                .append(",\"time\":\"").append(date(s.time)).append("\"}")
        }
        out.append("],\"startedAt\":\"").append(date(archive.startedAt)).append('"')
        out.append(",\"version\":").append(archive.version)
        out.append(",\"vertical\":").append(num(archive.vertical))
        out.append('}')
        return out.toString()
    }

    fun decode(text: String): SessionArchive {
        val json = JSONObject(text)
        val raw = json.optJSONArray("raw").objects().map {
            GeoSample(
                time = parseDate(it.getString("time")),
                latitude = it.getDouble("latitude"),
                longitude = it.getDouble("longitude"),
                altitude = it.getDouble("altitude"),
                horizontalAccuracy = it.getDouble("horizontalAccuracy"),
                gpsSpeed = if (it.has("gpsSpeed") && !it.isNull("gpsSpeed")) it.getDouble("gpsSpeed") else null,
            )
        }
        val samples = json.optJSONArray("samples").objects().map {
            TrackSample(
                id = it.optString("id").ifEmpty { newId() },
                time = parseDate(it.getString("time")),
                latitude = it.getDouble("latitude"),
                longitude = it.getDouble("longitude"),
                altitude = it.getDouble("altitude"),
                rawAltitude = it.optDouble("rawAltitude", it.getDouble("altitude")),
                speed = it.getDouble("speed"),
                accuracy = it.optDouble("accuracy", 5.0),
                segmentDistance = it.optDouble("segmentDistance", 0.0),
                phase = TrackPhase.from(it.optString("phase")),
            )
        }
        val runs = json.optJSONArray("runs").objects().map {
            RunRecord(
                id = it.optString("id").ifEmpty { newId() },
                index = it.getInt("index"),
                startedAt = parseDate(it.getString("startedAt")),
                endedAt = parseDate(it.getString("endedAt")),
                maxSpeed = it.getDouble("maxSpeed"),
                avgSpeed = it.optDouble("avgSpeed", 0.0),
                distance = it.getDouble("distance"),
                verticalDrop = it.getDouble("verticalDrop"),
                duration = it.optDouble("duration", 0.0),
            )
        }
        val jumps = json.optJSONArray("jumps").objects().map {
            JumpRecord(
                id = it.optString("id").ifEmpty { newId() },
                time = parseDate(it.getString("time")),
                duration = it.getDouble("duration"),
            )
        }
        return SessionArchive(
            version = json.optInt("version", SessionArchive.CURRENT_VERSION),
            id = json.getString("id"),
            startedAt = parseDate(json.getString("startedAt")),
            endedAt = if (json.has("endedAt") && !json.isNull("endedAt")) parseDate(json.getString("endedAt")) else null,
            resort = json.optString("resort"),
            riderName = json.optString("riderName"),
            isComplete = json.optBoolean("isComplete", true),
            isSample = json.optBoolean("isSample", false),
            raw = raw,
            samples = samples,
            runs = runs,
            jumps = jumps,
            maxSpeed = json.optDouble("maxSpeed", 0.0),
            distance = json.optDouble("distance", 0.0),
            vertical = json.optDouble("vertical", 0.0),
            duration = json.optDouble("duration", 0.0),
        )
    }

    private fun JSONArray?.objects(): List<JSONObject> =
        if (this == null) emptyList() else (0 until length()).map { getJSONObject(it) }

    private fun num(value: Double): String = if (value.isFinite()) value.toString() else "0"

    private fun quote(text: String): String = JSONObject.quote(text)
}
