package ch.geneve.slide.track

import android.content.Context
import android.location.Geocoder
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import ch.geneve.slide.data.DayStore
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Prefs
import ch.geneve.slide.data.Profile
import ch.geneve.slide.logic.AirtimeDetector
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.GeoSample
import ch.geneve.slide.logic.GpxCodec
import ch.geneve.slide.logic.JumpRecord
import ch.geneve.slide.logic.LiveSummary
import ch.geneve.slide.logic.ResortIndex
import ch.geneve.slide.logic.SampleDay
import ch.geneve.slide.logic.SessionArchive
import ch.geneve.slide.logic.SessionFile
import ch.geneve.slide.logic.SessionTracker
import ch.geneve.slide.logic.TrackPhase
import ch.geneve.slide.logic.TrackSample
import ch.geneve.slide.logic.newId
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import java.util.concurrent.Executors

enum class Activity { IDLE, TRACKING, PAUSED }

sealed class Notice {
    data object FileUnreadable : Notice()
    data object FileUnknown : Notice()
    data class GpxImported(val count: Int) : Notice()
    data class SessionImported(val name: String) : Notice()
    data object SampleAdded : Notice()
    data object SampleRemoved : Notice()

    fun message(): String = when (this) {
        FileUnreadable -> L10n.t("notice.file.unreadable")
        FileUnknown -> L10n.t("notice.file.unknown")
        is GpxImported -> L10n.t("notice.gpx", count)
        is SessionImported -> L10n.t("notice.session", name)
        SampleAdded -> L10n.t("notice.sample.added")
        SampleRemoved -> L10n.t("notice.sample.removed")
    }
}

/**
 * The live session: port of the iOS TrackingController. Runs on the main thread; [TrackService] feeds it sensor data
 * and keeps the process alive with a notification while tracking.
 */
object Tracking {
    var activity by mutableStateOf(Activity.IDLE); private set
    var summary by mutableStateOf(LiveSummary()); private set
    var jumpCount by mutableStateOf(0); private set
    var airtime by mutableStateOf(0.0); private set
    var usingBarometer by mutableStateOf(false); private set
    var resort by mutableStateOf(""); private set
    var startedAt by mutableStateOf<Double?>(null); private set
    var lastFixAt by mutableStateOf<Double?>(null); private set
    var notice by mutableStateOf<Notice?>(null)
    var lastArchive by mutableStateOf<SessionArchive?>(null)
    var mapSamples by mutableStateOf(listOf<TrackSample>()); private set
    var recoverableId by mutableStateOf<String?>(null); private set
    var recoverableTitle by mutableStateOf(""); private set
    var lowPower by mutableStateOf(false)

    private lateinit var app: Context
    private var tracker = SessionTracker()
    private val airtimeDetector = AirtimeDetector()
    private var jumps = mutableListOf<JumpRecord>()
    private var dayId: String? = null
    private var riderName = ""
    private var pauseAccumulated = 0.0
    private var pauseStarted: Double? = null
    private var acceptedSinceFlush = 0
    private var lastFlush = 0.0
    private var lastMapPush = 0.0
    private var lookedUpResort = false
    private var personalBest = 0.0
    private var baroOriginGps: Double? = null
    private var baroOriginRel: Double? = null
    private var latestRelative: Double? = null
    private val writer = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private const val ACTIVE_ID = "active_id"

    fun init(context: Context) {
        app = context.applicationContext
        refreshRecovery()
    }

    val isActive get() = activity != Activity.IDLE

    private fun now() = System.currentTimeMillis() / 1000.0

    fun duration(at: Double = now()): Double {
        if (activity == Activity.IDLE) return lastArchive?.duration ?: 0.0
        val start = startedAt ?: return 0.0
        val end = if (activity == Activity.PAUSED) pauseStarted ?: at else at
        return maxOf(0.0, end - start - pauseAccumulated)
    }

    // region Session control

    fun start() {
        val rider = Profile.name.trim()
        tracker = SessionTracker()
        jumps = mutableListOf()
        dayId = newId()
        riderName = rider
        resort = ""
        startedAt = now()
        pauseAccumulated = 0.0
        pauseStarted = null
        acceptedSinceFlush = 0
        lastFlush = 0.0
        lastArchive = null
        lastFixAt = null
        lookedUpResort = false
        notice = null
        baroOriginGps = null
        baroOriginRel = null
        latestRelative = null
        airtimeDetector.reset()
        activity = Activity.TRACKING
        recoverableId = null
        personalBest = DayStore.days.filterNot { it.isSample }.maxOfOrNull { it.maxSpeed } ?: 0.0
        Coach.resetSession(personalBest)
        Prefs.get(app).edit().putString(ACTIVE_ID, dayId).apply()
        flush(complete = false)
        publish()
        TrackService.start(app)
    }

    fun pause() {
        if (activity != Activity.TRACKING) return
        pauseStarted = now()
        activity = Activity.PAUSED
        flush(complete = false)
        publish()
        TrackService.refresh(app)
    }

    fun resume() {
        if (activity != Activity.PAUSED) return
        pauseStarted?.let { pauseAccumulated += now() - it }
        pauseStarted = null
        activity = Activity.TRACKING
        publish()
        TrackService.refresh(app)
    }

    fun stop() {
        if (activity == Activity.IDLE) return
        pauseStarted?.let { pauseAccumulated += now() - it }
        pauseStarted = null
        mapSamples = tracker.samples
        if (tracker.samples.isEmpty()) {
            // Same queue as the periodic saves, so an earlier save cannot land after this.
            dayId?.let { id -> writer.execute { DayStore.delete(id) } }
            lastArchive = null
        } else {
            flush(complete = true)
        }
        activity = Activity.IDLE
        Prefs.get(app).edit().remove(ACTIVE_ID).apply()
        Coach.release(app)
        TrackService.stop(app)
        refreshRecovery()
        publish()
    }

    /** Android restarted the killed service: pick the same day back up. */
    fun recoverActive(): Boolean {
        if (activity != Activity.IDLE) return true
        val id = Prefs.get(app).getString(ACTIVE_ID, null) ?: return false
        return resumeDay(id)
    }

    fun refreshRecovery() {
        if (activity != Activity.IDLE) {
            recoverableId = null
            return
        }
        val open = DayStore.days.filter { !it.isComplete }.maxByOrNull { it.startedAt }
        recoverableId = open?.id
        recoverableTitle = open?.let { day ->
            val time = Fmt.clock(day.startedAt)
            if (day.resort.isEmpty()) time else "${day.resort} · $time"
        } ?: ""
    }

    fun resumeRecovered() {
        val id = recoverableId ?: return
        if (resumeDay(id)) TrackService.start(app)
    }

    private fun resumeDay(id: String): Boolean {
        val archive = DayStore.read(id) ?: return false
        tracker = SessionTracker.replay(archive.raw)
        jumps = archive.jumps.toMutableList()
        dayId = archive.id
        startedAt = archive.startedAt
        resort = archive.resort
        riderName = archive.riderName
        pauseAccumulated = maxOf(0.0, now() - archive.startedAt - archive.duration)
        pauseStarted = null
        lastArchive = null
        recoverableId = null
        activity = Activity.TRACKING
        Prefs.get(app).edit().putString(ACTIVE_ID, id).apply()
        Coach.resetSession(DayStore.days.filterNot { it.isSample || it.id == id }.maxOfOrNull { it.maxSpeed } ?: 0.0)
        publish()
        return true
    }

    fun closeRecovered() {
        val id = recoverableId ?: return
        DayStore.read(id)?.let { DayStore.save(it.copy(isComplete = true, endedAt = it.endedAt ?: now())) }
        refreshRecovery()
    }

    // endregion

    // region Sensor input (main thread)

    fun onLocation(time: Double, lat: Double, lon: Double, gpsAltitude: Double, verticalAccuracy: Double?, accuracy: Double, speed: Double?) {
        if (activity != Activity.TRACKING || accuracy < 0) return
        val sample = GeoSample(time, lat, lon, fusedAltitude(gpsAltitude, verticalAccuracy), accuracy, speed)
        if (tracker.ingest(sample).accepted) {
            lastFixAt = now()
            acceptedSinceFlush += 1
        }
        publish()
        if (acceptedSinceFlush >= 12 || now() - lastFlush > 20) flush(complete = false)
    }

    fun onRelativeAltitude(meters: Double) {
        latestRelative = meters
        usingBarometer = true
    }

    fun onAcceleration(time: Double, magnitudeG: Double) {
        if (activity != Activity.TRACKING) return
        val s = summary
        val armed = s.speed > 5 || s.phase == TrackPhase.SKIING || s.openRun != null
        val hit = airtimeDetector.ingest(time, magnitudeG, armed) ?: return
        jumps.add(JumpRecord(time = now(), duration = hit))
        publish()
    }

    /** Barometer for smooth altitude, anchored to GPS altitude (same as iOS). */
    private fun fusedAltitude(gps: Double, verticalAccuracy: Double?): Double {
        val relative = latestRelative ?: return gps.also { usingBarometer = false }
        val vAcc = verticalAccuracy ?: -1.0
        if (baroOriginGps == null) {
            if (vAcc > 0 && vAcc < 25) {
                baroOriginGps = gps
                baroOriginRel = relative
            } else {
                return gps
            }
        }
        val originGps = baroOriginGps ?: return gps
        val originRel = baroOriginRel ?: return gps
        if (vAcc > 0 && vAcc < 12) {
            val implied = gps - (relative - originRel)
            baroOriginGps = originGps * 0.97 + implied * 0.03
        }
        return (baroOriginGps ?: originGps) + (relative - originRel)
    }

    // endregion

    private fun publish() {
        nameResortIfNeeded()
        summary = tracker.summary
        jumpCount = jumps.size
        airtime = jumps.sumOf { it.duration }
        val t = now()
        if (mapSamples.size != tracker.samples.size && t - lastMapPush > 0.8) {
            mapSamples = tracker.samples
            lastMapPush = t
        }
        if (activity == Activity.TRACKING) {
            Coach.consider(app, summary, tracker.runs, todayTotals().distance, duration(), Profile.units)
        }
        TrackService.update(app)
    }

    private fun archive(complete: Boolean): SessionArchive? {
        val id = dayId ?: return null
        val start = startedAt ?: return null
        val s = tracker.summary
        return SessionArchive(
            id = id, startedAt = start, endedAt = if (complete) now() else null, resort = resort.trim(),
            riderName = riderName, isComplete = complete, isSample = false, raw = tracker.raw.toList(),
            samples = tracker.samples, runs = tracker.runs, jumps = jumps.toList(), maxSpeed = s.maxSpeed,
            distance = s.distance, vertical = s.vertical, duration = duration(),
        )
    }

    /** Saves are queued on one thread in order, so the final save on Stop is always the last one. */
    private fun flush(complete: Boolean) {
        if (activity == Activity.IDLE && !complete) return
        if (tracker.samples.isEmpty() && !complete) return
        val archive = archive(complete) ?: return
        if (complete) lastArchive = archive
        acceptedSinceFlush = 0
        lastFlush = now()
        writer.execute { DayStore.save(archive) }
    }

    fun todayTotals(): Totals {
        val start = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toEpochSecond().toDouble()
        var total = Totals()
        for (day in DayStore.days) {
            if (day.startedAt < start || (isActive && day.id == dayId)) continue
            total = total.plus(day.distance, day.vertical, day.maxSpeed, day.runCount)
        }
        if (isActive) total = total.plus(summary.distance, summary.vertical, summary.maxSpeed, summary.qualifiedRuns)
        return total
    }

    data class Totals(val distance: Double = 0.0, val vertical: Double = 0.0, val maxSpeed: Double = 0.0, val runs: Int = 0) {
        fun plus(d: Double, v: Double, m: Double, r: Int) = Totals(distance + d, vertical + v, maxOf(maxSpeed, m), runs + r)
    }

    private fun nameResortIfNeeded() {
        if (resort.isNotBlank() || tracker.samples.size < 8) return
        ResortIndex.match(tracker.samples)?.let {
            resort = it.name
            return
        }
        if (lookedUpResort) return
        lookedUpResort = true
        val last = tracker.samples.last()
        writer.execute {
            @Suppress("DEPRECATION")
            val name = runCatching {
                Geocoder(app, Locale.getDefault()).getFromLocation(last.latitude, last.longitude, 1)?.firstOrNull()
                    ?.let { it.locality ?: it.subAdminArea ?: it.adminArea }
            }.getOrNull()
            if (!name.isNullOrBlank()) main.post { if (resort.isBlank()) resort = name }
        }
    }

    // region History actions

    fun importUri(context: Context, uri: Uri) {
        val name = uri.lastPathSegment?.substringAfterLast('/')?.lowercase() ?: ""
        val text = runCatching {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
        }.getOrNull()
        if (text == null) {
            notice = Notice.FileUnreadable
            return
        }
        importText(text, name)
    }

    fun importText(text: String, filename: String) {
        val trimmed = text.trimStart()
        val looksJson = trimmed.startsWith("{") || filename.endsWith(".slide") || filename.endsWith(".glisse")
        if (looksJson) {
            val archive = runCatching { SessionFile.decode(text) }.getOrNull()
            if (archive == null) {
                notice = Notice.FileUnreadable
                return
            }
            val exists = DayStore.days.any { it.id.equals(archive.id, ignoreCase = true) }
            val saved = if (exists) archive.copy(id = newId()) else archive
            DayStore.save(saved.copy(isComplete = true))
            notice = Notice.SessionImported(saved.resort.ifEmpty { Fmt.dayShort(saved.startedAt, L10n.locale) })
            return
        }
        if (trimmed.startsWith("<") || filename.endsWith(".gpx")) {
            val points = runCatching { GpxCodec.parse(text) }.getOrNull()
            if (points.isNullOrEmpty()) {
                notice = Notice.FileUnreadable
                return
            }
            val replay = SessionTracker.replay(points)
            val s = replay.summary
            val start = points.first().time
            val end = points.last().time
            DayStore.save(
                SessionArchive(
                    id = newId(), startedAt = start, endedAt = end, resort = ResortIndex.match(replay.samples)?.name ?: "",
                    riderName = Profile.name, isComplete = true, isSample = false, raw = points, samples = replay.samples,
                    runs = replay.runs, jumps = emptyList(), maxSpeed = s.maxSpeed, distance = s.distance,
                    vertical = s.vertical, duration = end - start,
                ),
            )
            notice = Notice.GpxImported(replay.runs.size)
            return
        }
        notice = Notice.FileUnknown
    }

    fun toggleSampleDay() {
        val existing = DayStore.days.filter { it.isSample }
        if (existing.isNotEmpty()) {
            existing.forEach { DayStore.delete(it.id) }
            notice = Notice.SampleRemoved
        } else {
            DayStore.save(SampleDay.make())
            notice = Notice.SampleAdded
        }
    }

    fun eraseAll() {
        if (isActive) stop()
        DayStore.eraseAll()
        ch.geneve.slide.data.TrickNotes.clear()
        refreshRecovery()
    }

    // endregion
}
