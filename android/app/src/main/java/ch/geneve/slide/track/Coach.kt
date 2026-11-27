package ch.geneve.slide.track

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import ch.geneve.slide.data.CoachSettings
import ch.geneve.slide.data.L10n
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.LiveSummary
import ch.geneve.slide.logic.RunRecord
import ch.geneve.slide.logic.UnitPrefs
import java.util.Locale

/** Headset voice coach, port of the iOS AudioCoach: same cues, same phrases, in the app language. */
object Coach {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var queued: String? = null
    @Volatile private var focus: AudioFocusRequest? = null

    private var lastSpoken = 0L
    private var pending: String? = null
    private var primed = false
    private var thresholdArmed = true
    private var announcedDayMax = 0.0
    private var announcedPersonal = 0.0
    private var distanceBucket = 0
    private var lastPeriodic = 0L
    private var spokenRuns = 0

    fun resetSession(personalBest: Double) {
        primed = false
        thresholdArmed = true
        announcedDayMax = 0.0
        announcedPersonal = personalBest
        distanceBucket = 0
        lastPeriodic = System.currentTimeMillis()
        spokenRuns = 0
        pending = null
    }

    fun test(context: Context) = speak(context, L10n.t("audio.say.test"), force = true)

    /** "Max speed today …" / "Distance today …" for the launcher shortcuts. */
    fun say(context: Context, text: String) = speak(context, text, force = true)

    fun consider(
        context: Context,
        summary: LiveSummary,
        runs: List<RunRecord>,
        todayDistance: Double,
        elapsed: Double,
        prefs: UnitPrefs,
    ) {
        if (!CoachSettings.enabled) return
        flushPending(context)
        val now = System.currentTimeMillis()
        if (!primed) {
            primed = true
            announcedDayMax = summary.maxSpeed
            announcedPersonal = maxOf(announcedPersonal, summary.maxSpeed)
            distanceBucket = bucket(todayDistance)
            spokenRuns = runs.size
            lastPeriodic = now
            return
        }
        val kmh = summary.speed * 3.6
        val mark = CoachSettings.thresholdKmh
        if (runs.size > spokenRuns || kmh < mark - 10) thresholdArmed = true
        var phrase: String? = null
        if (runs.size > spokenRuns && runs.isNotEmpty()) {
            spokenRuns = runs.size
            phrase = runLine(runs.last(), prefs)
        } else if (summary.maxSpeed > announcedPersonal + 0.28) {
            announcedPersonal = summary.maxSpeed
            phrase = L10n.t("audio.say.record", speed(summary.maxSpeed, prefs))
        } else if (summary.maxSpeed > announcedDayMax + 0.28) {
            announcedDayMax = summary.maxSpeed
            phrase = L10n.t("audio.say.day", speed(summary.maxSpeed, prefs))
        } else if (thresholdArmed && kmh >= mark) {
            thresholdArmed = false
            phrase = L10n.t("audio.say.over", speed(mark / 3.6, prefs))
        } else {
            val next = bucket(todayDistance)
            if (next > distanceBucket) {
                distanceBucket = next
                phrase = L10n.t("audio.say.distance", Fmt.distance(todayDistance, prefs, L10n.frenchNumbers))
            } else if (CoachSettings.periodMinutes > 0 && now - lastPeriodic >= CoachSettings.periodMinutes * 60_000L) {
                lastPeriodic = now
                phrase = (listOf(L10n.t("audio.say.update")) + parts(summary, todayDistance, runs.size, prefs)).joinToString(" ")
            }
        }
        phrase?.let { queue(context, it) }
        flushPending(context)
    }

    private fun bucket(meters: Double) = (meters / (CoachSettings.everyKm * 1000)).toInt()

    private fun parts(summary: LiveSummary, todayDistance: Double, runCount: Int, prefs: UnitPrefs): List<String> {
        val f = L10n.frenchNumbers
        val lines = mutableListOf<String>()
        if (CoachSettings.part("distance")) lines += L10n.t("audio.say.distance", Fmt.distance(todayDistance, prefs, f))
        if (CoachSettings.part("speed")) lines += L10n.t("audio.say.speed", speed(summary.speed, prefs))
        if (CoachSettings.part("max")) lines += L10n.t("audio.say.max", speed(summary.maxSpeed, prefs))
        if (CoachSettings.part("vertical")) lines += L10n.t("audio.say.vertical", Fmt.altitude(summary.vertical, prefs, f))
        if (CoachSettings.part("runs")) lines += L10n.t("audio.say.runs", runCount)
        if (lines.isEmpty()) lines += L10n.t("audio.say.speed", speed(summary.speed, prefs))
        return lines
    }

    private fun runLine(run: RunRecord, prefs: UnitPrefs): String {
        val f = L10n.frenchNumbers
        return listOf(
            L10n.t("audio.say.run", run.index),
            L10n.t("audio.say.max", speed(run.maxSpeed, prefs)),
            L10n.t("audio.say.distance", Fmt.distance(run.distance, prefs, f)),
            L10n.t("audio.say.vertical", Fmt.altitude(run.verticalDrop, prefs, f)),
        ).joinToString(" ")
    }

    private fun speed(mps: Double, prefs: UnitPrefs) = Fmt.speed(mps, prefs, L10n.frenchNumbers) + " " + Fmt.speedUnit(prefs)

    private fun queue(context: Context, text: String) {
        if (System.currentTimeMillis() - lastSpoken < 8_000 || tts?.isSpeaking == true) {
            pending = text
            return
        }
        speak(context, text, force = false)
    }

    private fun flushPending(context: Context) {
        val text = pending ?: return
        if (System.currentTimeMillis() - lastSpoken < 8_000 || tts?.isSpeaking == true) return
        pending = null
        speak(context, text, force = false)
    }

    private fun speak(context: Context, text: String, force: Boolean) {
        val app = context.applicationContext
        lastSpoken = System.currentTimeMillis()
        val engine = tts
        if (engine == null || !ready) {
            queued = text
            if (engine == null) {
                tts = TextToSpeech(app) { status ->
                    ready = status == TextToSpeech.SUCCESS
                    queued?.takeIf { ready }?.let { queued = null; utter(app, it, true) }
                }.apply {
                    setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) = Unit
                        override fun onDone(utteranceId: String?) = release(app)
                        @Deprecated("Deprecated in Java")
                        override fun onError(utteranceId: String?) = release(app)
                    })
                }
            }
            return
        }
        utter(app, text, force)
    }

    private fun utter(context: Context, text: String, force: Boolean) {
        val engine = tts ?: return
        val audio = context.getSystemService(AudioManager::class.java)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        synchronized(this) {
            release(context)
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK).setAudioAttributes(attrs).build()
            audio.requestAudioFocus(request)
            focus = request
        }
        engine.setAudioAttributes(attrs)
        engine.language = voice(L10n.code)
        engine.speak(text, if (force) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD, null, "slide-${System.nanoTime()}")
    }

    /** Give the audio back to music at full volume. */
    @Synchronized
    fun release(context: Context) {
        val request = focus ?: return
        focus = null
        context.getSystemService(AudioManager::class.java).abandonAudioFocusRequest(request)
    }

    private fun voice(code: String): Locale = when (code) {
        "fr" -> Locale.FRANCE
        "de" -> Locale.GERMANY
        "it" -> Locale.ITALY
        "es" -> Locale.forLanguageTag("es-ES")
        "pt" -> Locale.forLanguageTag("pt-PT")
        "nl" -> Locale.forLanguageTag("nl-NL")
        "sv" -> Locale.forLanguageTag("sv-SE")
        "nb" -> Locale.forLanguageTag("nb-NO")
        "pl" -> Locale.forLanguageTag("pl-PL")
        "cs" -> Locale.forLanguageTag("cs-CZ")
        "ja" -> Locale.JAPAN
        "ko" -> Locale.KOREA
        "zh-Hans" -> Locale.SIMPLIFIED_CHINESE
        else -> Locale.UK
    }
}
