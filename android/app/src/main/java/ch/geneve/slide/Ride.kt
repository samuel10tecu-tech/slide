package ch.geneve.slide

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

data class Sample(val t: Long, val lat: Double, val lon: Double, val alt: Double, val speed: Double)
data class Run(val index: Int, var max: Double, var distance: Double, var vertical: Double)
data class DayFile(
    val id: String,
    val started: Long,
    var resort: String,
    var max: Double,
    var distance: Double,
    var vertical: Double,
    val runs: List<Run>,
    val lat: Double,
    val lon: Double,
    val track: List<Sample>
)

class Engine {
    val runs = mutableListOf<Run>()
    var phase = "rest"
    var distance = 0.0
    var vertical = 0.0
    var maxSpeed = 0.0
    private val window = ArrayDeque<Sample>()
    private var open: Run? = null
    private var last: Sample? = null
    private var openDistance = 0.0
    private var openVertical = 0.0

    fun clear() {
        runs.clear()
        phase = "rest"
        distance = 0.0
        vertical = 0.0
        maxSpeed = 0.0
        window.clear()
        open = null
        last = null
        openDistance = 0.0
        openVertical = 0.0
    }

    fun add(sample: Sample) {
        val prev = last
        last = sample
        maxSpeed = max(maxSpeed, sample.speed)
        var step = 0.0
        if (prev != null) {
            val dt = (sample.t - prev.t) / 1000.0
            val moved = haversine(prev.lat, prev.lon, sample.lat, sample.lon)
            if (dt in 0.3..45.0 && sample.speed < 55 && moved < 250) step = moved
        }
        window.addLast(sample)
        while (window.size > 6) window.removeFirst()
        val next = classify(sample)
        if (next == "ski") {
            distance += step
            val drop = (prev?.alt ?: sample.alt) - sample.alt
            if (drop > 0) vertical += drop
            if (open == null) {
                open = Run(runs.size + 1, sample.speed, 0.0, 0.0)
                openDistance = 0.0
                openVertical = 0.0
            }
            openDistance += step
            val dropOpen = (prev?.alt ?: sample.alt) - sample.alt
            if (dropOpen > 0) openVertical += dropOpen
            open?.apply {
                max = max(max, sample.speed)
                distance = openDistance
                vertical = openVertical
            }
        } else if (open != null) {
            val finished = open!!
            if (finished.distance >= 25 || finished.vertical >= 8) runs.add(finished)
            open = null
        }
        phase = next
    }

    private fun classify(sample: Sample): String {
        if (window.size < 4) return phase
        val climb = window.last().alt - window.first().alt
        val span = ((window.last().t - window.first().t) / 1000.0).coerceAtLeast(1.0)
        val rate = climb / span
        return when {
            sample.speed > 2.2 && rate < -0.25 -> "ski"
            sample.speed in 0.8..9.0 && rate > 0.3 -> "lift"
            sample.speed < 1.0 -> "rest"
            else -> phase
        }
    }
}

fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val r = 6_371_000.0
    val p1 = lat1 * PI / 180
    val p2 = lat2 * PI / 180
    val dp = (lat2 - lat1) * PI / 180
    val dl = (lon2 - lon1) * PI / 180
    val a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
    return 2 * r * atan2(sqrt(a), sqrt(1 - a))
}

object DayStore {
    private fun dir(context: Context) = File(context.filesDir, "days").apply { mkdirs() }

    fun save(context: Context, day: DayFile) {
        val file = File(dir(context), "${day.id}.json")
        val runs = JSONArray()
        day.runs.forEach {
            runs.put(JSONObject().put("index", it.index).put("max", it.max).put("distance", it.distance).put("vertical", it.vertical))
        }
        val track = JSONArray()
        day.track.forEach { track.put(JSONArray().put(it.lat).put(it.lon).put(it.speed)) }
        val json = JSONObject()
            .put("id", day.id)
            .put("started", day.started)
            .put("resort", day.resort)
            .put("max", day.max)
            .put("distance", day.distance)
            .put("vertical", day.vertical)
            .put("lat", day.lat)
            .put("lon", day.lon)
            .put("runs", runs)
            .put("track", track)
        file.writeText(json.toString())
    }

    fun load(context: Context): List<DayFile> {
        return dir(context).listFiles { f -> f.extension == "json" }.orEmpty().mapNotNull { file ->
            runCatching {
                val json = JSONObject(file.readText())
                val runsJson = json.getJSONArray("runs")
                val runs = (0 until runsJson.length()).map { i ->
                    val row = runsJson.getJSONObject(i)
                    Run(row.getInt("index"), row.getDouble("max"), row.getDouble("distance"), row.getDouble("vertical"))
                }
                val trackJson = json.optJSONArray("track") ?: JSONArray()
                val track = (0 until trackJson.length()).map { i ->
                    val row = trackJson.getJSONArray(i)
                    Sample(0, row.getDouble(0), row.getDouble(1), 0.0, row.getDouble(2))
                }
                DayFile(
                    json.getString("id"), json.getLong("started"), json.optString("resort"),
                    json.getDouble("max"), json.getDouble("distance"), json.getDouble("vertical"),
                    runs, json.optDouble("lat"), json.optDouble("lon"), track
                )
            }.getOrNull()
        }.sortedByDescending { it.started }
    }

    fun newId() = UUID.randomUUID().toString()

    fun gpx(day: DayFile): String {
        val points = day.track.joinToString("\n") { "<trkpt lat=\"${it.lat}\" lon=\"${it.lon}\"></trkpt>" }
        return """<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1" creator="Slide"><trk><name>Slide</name><trkseg>$points</trkseg></trk></gpx>"""
    }
}
