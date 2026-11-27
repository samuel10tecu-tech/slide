package ch.geneve.slide.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import ch.geneve.slide.logic.UnitPrefs
import org.json.JSONObject

object Prefs {
    fun get(context: Context): SharedPreferences = context.applicationContext.getSharedPreferences("slide", Context.MODE_PRIVATE)
}

/** Rider profile and display choices (the iOS RiderProfile), observable from Compose. */
object Profile {
    private lateinit var prefs: SharedPreferences

    var name by mutableStateOf("")
        private set
    var homeMountain by mutableStateOf("")
        private set
    var units by mutableStateOf(UnitPrefs.METRIC)
        private set
    var keepScreenOn by mutableStateOf(false)
        private set
    /** Map legend: colour by this day's own top speed instead of absolute km/h. */
    var relativeSpeed by mutableStateOf(false)
        private set

    fun init(context: Context) {
        prefs = Prefs.get(context)
        name = prefs.getString("profile.name", "") ?: ""
        homeMountain = prefs.getString("profile.home", "") ?: ""
        units = UnitPrefs(
            prefs.getBoolean("profile.speedMetric", true),
            prefs.getBoolean("profile.distanceMetric", true),
            prefs.getBoolean("profile.altitudeMetric", true),
        )
        keepScreenOn = prefs.getBoolean("profile.keepScreenOn", false)
        relativeSpeed = prefs.getBoolean("slide.speed.relative", false)
    }

    fun saveName(value: String) { name = value; prefs.edit().putString("profile.name", value).apply() }
    fun saveHome(value: String) { homeMountain = value; prefs.edit().putString("profile.home", value).apply() }
    fun saveKeepScreenOn(value: Boolean) { keepScreenOn = value; prefs.edit().putBoolean("profile.keepScreenOn", value).apply() }
    fun saveRelative(value: Boolean) { relativeSpeed = value; prefs.edit().putBoolean("slide.speed.relative", value).apply() }

    fun saveUnits(value: UnitPrefs) {
        units = value
        prefs.edit()
            .putBoolean("profile.speedMetric", value.speedMetric)
            .putBoolean("profile.distanceMetric", value.distanceMetric)
            .putBoolean("profile.altitudeMetric", value.altitudeMetric)
            .apply()
    }
}

/** Voice coach settings (iOS AudioCoachSettings). */
object CoachSettings {
    private lateinit var prefs: SharedPreferences

    var enabled by mutableStateOf(false); private set
    var thresholdKmh by mutableStateOf(60.0); private set
    var everyKm by mutableStateOf(1.0); private set
    var periodMinutes by mutableStateOf(0); private set
    var parts by mutableStateOf(mapOf<String, Boolean>()); private set

    val partKeys = listOf("distance", "speed", "max", "vertical", "runs")

    fun init(context: Context) {
        prefs = Prefs.get(context)
        enabled = prefs.getBoolean("audio", false)
        thresholdKmh = prefs.getFloat("threshold", 60f).toDouble()
        everyKm = prefs.getFloat("every", 1f).toDouble().coerceIn(0.5, 10.0)
        periodMinutes = prefs.getInt("period", 0)
        parts = partKeys.associateWith { prefs.getBoolean("audio.part.$it", true) }
    }

    fun saveEnabled(value: Boolean) { enabled = value; prefs.edit().putBoolean("audio", value).apply() }
    fun saveThreshold(value: Double) { thresholdKmh = value; prefs.edit().putFloat("threshold", value.toFloat()).apply() }
    fun saveEvery(value: Double) { everyKm = value; prefs.edit().putFloat("every", value.toFloat()).apply() }
    fun savePeriod(value: Int) { periodMinutes = value; prefs.edit().putInt("period", value).apply() }
    fun savePart(key: String, value: Boolean) {
        parts = parts + (key to value)
        prefs.edit().putBoolean("audio.part.$key", value).apply()
    }
    fun part(key: String) = parts[key] ?: true
}

/** Freestyle checklist and notes (iOS TrickEntry). */
object TrickNotes {
    data class Entry(val learned: Boolean = false, val learnedAt: Double? = null, val note: String = "")

    private lateinit var prefs: SharedPreferences
    var entries by mutableStateOf(mapOf<String, Entry>()); private set

    fun init(context: Context) {
        prefs = Prefs.get(context)
        val json = runCatching { JSONObject(prefs.getString("tricks", "{}") ?: "{}") }.getOrElse { JSONObject() }
        entries = json.keys().asSequence().associateWith { id ->
            val row = json.getJSONObject(id)
            Entry(row.optBoolean("learned"), if (row.has("learnedAt")) row.getDouble("learnedAt") else null, row.optString("note"))
        }
    }

    fun entry(id: String) = entries[id] ?: Entry()

    fun update(id: String, change: (Entry) -> Entry) {
        entries = entries + (id to change(entry(id)))
        save()
    }

    fun clear() {
        entries = emptyMap()
        save()
    }

    private fun save() {
        val json = JSONObject()
        entries.forEach { (id, e) ->
            val row = JSONObject().put("learned", e.learned).put("note", e.note)
            e.learnedAt?.let { row.put("learnedAt", it) }
            json.put(id, row)
        }
        prefs.edit().putString("tricks", json.toString()).apply()
    }
}
