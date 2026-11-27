package ch.geneve.slide.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import ch.geneve.slide.logic.GeoSample
import ch.geneve.slide.logic.RunRecord
import ch.geneve.slide.logic.SessionArchive
import ch.geneve.slide.logic.SessionFile
import ch.geneve.slide.logic.SessionTracker
import org.json.JSONObject
import java.io.File

/** What the History list needs about a day, without loading its whole track (iOS SkiDay). */
data class DayMeta(
    val id: String,
    val startedAt: Double,
    val endedAt: Double?,
    val resort: String,
    val riderName: String,
    val isComplete: Boolean,
    val isSample: Boolean,
    val maxSpeed: Double,
    val distance: Double,
    val vertical: Double,
    val duration: Double,
    val runCount: Int,
    val jumpCount: Int,
    val airtime: Double,
    val longestRun: Double,
    val latitude: Double,
    val longitude: Double,
) {
    fun toJson(): String = JSONObject()
        .put("id", id).put("startedAt", startedAt).put("endedAt", endedAt ?: JSONObject.NULL)
        .put("resort", resort).put("riderName", riderName).put("isComplete", isComplete).put("isSample", isSample)
        .put("maxSpeed", maxSpeed).put("distance", distance).put("vertical", vertical).put("duration", duration)
        .put("runCount", runCount).put("jumpCount", jumpCount).put("airtime", airtime).put("longestRun", longestRun)
        .put("latitude", latitude).put("longitude", longitude).toString()

    companion object {
        fun of(a: SessionArchive): DayMeta {
            val points = a.samples
            return DayMeta(
                a.id, a.startedAt, a.endedAt, a.resort, a.riderName, a.isComplete, a.isSample, a.maxSpeed, a.distance,
                a.vertical, a.duration, a.runs.size, a.jumpCount, a.airtime, a.longestRunDistance,
                if (points.isEmpty()) 0.0 else points.sumOf { it.latitude } / points.size,
                if (points.isEmpty()) 0.0 else points.sumOf { it.longitude } / points.size,
            )
        }

        fun parse(text: String): DayMeta {
            val j = JSONObject(text)
            return DayMeta(
                j.getString("id"), j.getDouble("startedAt"), if (j.isNull("endedAt")) null else j.getDouble("endedAt"),
                j.optString("resort"), j.optString("riderName"), j.optBoolean("isComplete", true), j.optBoolean("isSample"),
                j.optDouble("maxSpeed", 0.0), j.optDouble("distance", 0.0), j.optDouble("vertical", 0.0),
                j.optDouble("duration", 0.0), j.optInt("runCount"), j.optInt("jumpCount"), j.optDouble("airtime", 0.0),
                j.optDouble("longestRun", 0.0), j.optDouble("latitude", 0.0), j.optDouble("longitude", 0.0),
            )
        }
    }
}

/**
 * Days live in files/days as <id>.slide (the full archive, same JSON as iOS) plus a small <id>.meta.json.
 * [days] is observable so every screen updates after a save.
 */
object DayStore {
    private lateinit var dir: File
    var days by mutableStateOf(listOf<DayMeta>())
        private set
    private val lock = Any()

    fun init(context: Context) {
        dir = File(context.filesDir, "days").apply { mkdirs() }
        migrateLegacy()
        reload()
    }

    fun reload() {
        val list = dir.listFiles { f -> f.name.endsWith(".meta.json") }.orEmpty().mapNotNull {
            runCatching { DayMeta.parse(it.readText()) }.getOrNull()
        }
        days = list.sortedByDescending { it.startedAt }
    }

    fun read(id: String): SessionArchive? = synchronized(lock) {
        runCatching { SessionFile.decode(File(dir, "$id.slide").readText()) }.getOrNull()
    }

    /** Writes the archive and its summary. Safe to call from a background thread. */
    fun save(archive: SessionArchive) {
        val meta = DayMeta.of(archive)
        synchronized(lock) {
            atomic(File(dir, "${archive.id}.slide"), SessionFile.encode(archive))
            atomic(File(dir, "${archive.id}.meta.json"), meta.toJson())
        }
        val updated = days.filterNot { it.id == meta.id } + meta
        days = updated.sortedByDescending { it.startedAt }
    }

    fun delete(id: String) {
        synchronized(lock) {
            File(dir, "$id.slide").delete()
            File(dir, "$id.meta.json").delete()
        }
        days = days.filterNot { it.id == id }
    }

    fun rename(id: String, resort: String) {
        val archive = read(id) ?: return
        if (archive.resort != resort) save(archive.copy(resort = resort))
    }

    fun eraseAll() {
        synchronized(lock) { dir.listFiles().orEmpty().forEach { it.delete() } }
        days = emptyList()
    }

    private fun atomic(file: File, text: String) {
        val temp = File(file.parentFile, file.name + ".tmp")
        temp.writeText(text)
        if (!temp.renameTo(file)) {
            file.writeText(text)
            temp.delete()
        }
    }

    /** Days saved by Slide for Android 1.5 and earlier (<id>.json with a short track) become .slide archives. */
    private fun migrateLegacy() {
        dir.listFiles { f -> f.name.endsWith(".json") && !f.name.endsWith(".meta.json") }.orEmpty().forEach { file ->
            runCatching {
                val j = JSONObject(file.readText())
                val started = j.getLong("started") / 1000.0
                val track = j.optJSONArray("track")
                val raw = (0 until (track?.length() ?: 0)).map { i ->
                    val row = track!!.getJSONArray(i)
                    val t = row.optLong(3, 0L)
                    GeoSample(
                        time = if (t > 0) t / 1000.0 else started + i,
                        latitude = row.getDouble(0),
                        longitude = row.getDouble(1),
                        altitude = row.optDouble(4, 0.0),
                        horizontalAccuracy = 5.0,
                        gpsSpeed = row.getDouble(2),
                    )
                }
                val tracker = SessionTracker.replay(raw)
                val runsJson = j.optJSONArray("runs")
                val runs = (0 until (runsJson?.length() ?: 0)).map { i ->
                    val r = runsJson!!.getJSONObject(i)
                    RunRecord(
                        index = r.getInt("index"), startedAt = started, endedAt = started, maxSpeed = r.getDouble("max"),
                        avgSpeed = 0.0, distance = r.getDouble("distance"), verticalDrop = r.getDouble("vertical"), duration = 0.0,
                    )
                }
                val ended = raw.lastOrNull()?.time ?: started
                val archive = SessionArchive(
                    id = j.getString("id").uppercase(), startedAt = started, endedAt = ended,
                    resort = j.optString("resort"), riderName = "", isComplete = true, isSample = false,
                    raw = raw, samples = tracker.samples, runs = runs, jumps = emptyList(),
                    maxSpeed = j.optDouble("max", 0.0), distance = j.optDouble("distance", 0.0),
                    vertical = j.optDouble("vertical", 0.0), duration = ended - started,
                )
                save(archive)
                file.delete()
            }
        }
    }
}
