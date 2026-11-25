package ch.geneve.slide

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.speech.tts.TextToSpeech
import java.util.Locale

object Coach {
    private var tts: TextToSpeech? = null
    private var lastSpoken = 0L
    private var armed = true
    private var bucket = 0
    private var lastMark = 0.0
    private var announcedRuns = 0
    private var lastPeriodic = 0L

    fun speak(context: Context, text: String, force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastSpoken < 8_000) return
        if (tts == null) {
            tts = TextToSpeech(context.applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) say(context, text)
            }
            return
        }
        say(context, text)
    }

    private fun say(context: Context, text: String) {
        val audio = context.getSystemService(AudioManager::class.java)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attrs)
            .build()
        audio.requestAudioFocus(focus)
        val prefs = context.getSharedPreferences("slide", Context.MODE_PRIVATE)
        val lang = prefs.getString("lang", "en") ?: "en"
        tts?.language = when (lang) {
            "fr" -> Locale.FRENCH
            "de" -> Locale.GERMAN
            else -> Locale.UK
        }
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "slide")
        lastSpoken = System.currentTimeMillis()
    }

    fun consider(context: Context) {
        val prefs = context.getSharedPreferences("slide", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("audio", false)) return
        val kmh = Live.speed * 3.6
        val threshold = prefs.getFloat("threshold", 60f).toDouble()
        val every = prefs.getFloat("every", 1f).toDouble().coerceIn(0.5, 10.0)
        val minutes = prefs.getInt("period", 0)
        val km = Live.engine.distance / 1000.0
        val nextBucket = (km / every).toInt()
        val now = System.currentTimeMillis()
        val line = StringBuilder()
        if (Live.engine.runs.size > announcedRuns) {
            announcedRuns = Live.engine.runs.size
            val run = Live.engine.runs.last()
            line.append("Run ${run.index}. Max ${fmt(run.max)}. ")
        } else if (armed && kmh >= threshold) {
            armed = false
            line.append("Over ${fmt(Live.speed)}. ")
        } else if (nextBucket > bucket && bucket > 0) {
            line.append("${"%.1f".format(km)} km. Speed ${fmt(Live.speed)}. ")
        }
        bucket = nextBucket
        if (kmh < threshold - 8) armed = true
        if (Live.engine.maxSpeed > lastMark + 0.3) {
            lastMark = Live.engine.maxSpeed
            if (line.isEmpty()) line.append("Max ${fmt(Live.engine.maxSpeed)}. ")
        }
        if (minutes > 0 && now - lastPeriodic > minutes * 60_000L) {
            lastPeriodic = now
            if (line.isEmpty()) line.append("${"%.1f".format(km)} km. ")
        }
        if (prefs.getBoolean("sayDistance", true) && line.isNotEmpty()) line.append("${"%.1f".format(km)} km. ")
        if (prefs.getBoolean("saySpeed", true) && line.isNotEmpty()) line.append("${fmt(Live.speed)}. ")
        if (line.isNotBlank()) speak(context, line.toString())
    }

    fun test(context: Context) = speak(context, context.getString(R.string.hear_me), force = true)

    private fun fmt(mps: Double) = "${"%.0f".format(mps * 3.6)} km/h"

    fun todayMax(context: Context): Double {
        val start = startOfDay()
        return DayStore.load(context).filter { it.started >= start }.maxOfOrNull { it.max } ?: Live.engine.maxSpeed
    }

    fun todayDistance(context: Context): Double {
        val start = startOfDay()
        return DayStore.load(context).filter { it.started >= start }.sumOf { it.distance } + if (Live.tracking) Live.engine.distance else 0.0
    }

    private fun startOfDay(): Long {
        val cal = java.util.Calendar.getInstance()
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        return cal.timeInMillis
    }
}
