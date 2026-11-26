package ch.geneve.slide

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

object Live {
    @Volatile var tracking = false
    val samples = CopyOnWriteArrayList<Sample>()
    val engine = Engine()
    @Volatile var speed = 0.0
    @Volatile var phase = "rest"
    var id = ""
    var started = 0L

    fun reset() {
        samples.clear()
        engine.clear()
        speed = 0.0
        phase = "rest"
        id = DayStore.newId()
        started = System.currentTimeMillis()
    }
}

class TrackService : Service() {
    private var manager: LocationManager? = null
    private val listener = LocationListener { location -> onFix(location) }
    private val writer = Executors.newSingleThreadExecutor()
    private var lastSave = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(7, note(), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(7, note())
        }
        // Android restarts a sticky service with a fresh process after killing it.
        // Pick the session back up instead of saving a day with no id.
        if (Live.id.isEmpty() && !recover()) {
            stopSelf()
            return START_NOT_STICKY
        }
        Live.tracking = true
        listen()
        return START_STICKY
    }

    private fun recover(): Boolean {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val id = prefs.getString(ACTIVE_ID, null) ?: return false
        Live.samples.clear()
        Live.id = id
        Live.started = prefs.getLong(ACTIVE_STARTED, System.currentTimeMillis())
        val saved = DayStore.find(this, id)?.track.orEmpty().filter { it.t > 0 }
        Live.samples.addAll(saved)
        Live.engine.replay(saved)
        Live.speed = 0.0
        Live.phase = Live.engine.phase
        return true
    }

    /** Requests updates even when GPS is off: they start as soon as it is turned on. */
    @SuppressLint("MissingPermission")
    private fun listen() {
        val location = getSystemService(LocationManager::class.java)
        manager?.removeUpdates(listener)
        manager = location
        location.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 3f, listener)
    }

    private fun onFix(location: Location) {
        val speed = if (location.hasSpeed()) location.speed.toDouble().coerceAtLeast(0.0) else 0.0
        val sample = Sample(location.time, location.latitude, location.longitude, location.altitude, speed)
        Live.samples.add(sample)
        Live.engine.add(sample)
        Live.speed = speed
        Live.phase = Live.engine.phase
        Coach.consider(this)
        val now = System.currentTimeMillis()
        if (now - lastSave >= SAVE_EVERY_MS) {
            lastSave = now
            save(background = true)
        }
    }

    private fun note(): Notification {
        val channel = "slide.track"
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(channel, "Slide", NotificationManager.IMPORTANCE_LOW))
        return NotificationCompat.Builder(this, channel)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(getString(R.string.notify_title))
            .setContentText(getString(R.string.notify_text))
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        manager?.removeUpdates(listener)
        Live.tracking = false
        Live.engine.finish()
        // Let a periodic write finish before the final one replaces the same file.
        writer.shutdown()
        runCatching { writer.awaitTermination(3, TimeUnit.SECONDS) }
        save(background = false)
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(ACTIVE_ID).remove(ACTIVE_STARTED).apply()
        Coach.release(this)
        super.onDestroy()
    }

    /** Snapshot the session now; the JSON is written off the main thread while tracking. */
    private fun save(background: Boolean) {
        val track = Live.samples.toList()
        if (track.isEmpty() || Live.id.isEmpty()) return
        val day = DayFile(
            Live.id, Live.started, "", Live.engine.maxSpeed, Live.engine.distance, Live.engine.vertical,
            Live.engine.runs.toList(), track.map { it.lat }.average(), track.map { it.lon }.average(), track
        )
        val context = applicationContext
        if (background) {
            writer.execute { DayStore.save(context, day) }
        } else {
            DayStore.save(context, day)
        }
    }

    companion object {
        const val ACTION_STOP = "ch.geneve.slide.STOP"
        private const val PREFS = "slide"
        private const val ACTIVE_ID = "active_id"
        private const val ACTIVE_STARTED = "active_started"
        private const val SAVE_EVERY_MS = 20_000L

        fun start(context: Context) {
            Live.reset()
            Coach.reset()
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(ACTIVE_ID, Live.id)
                .putLong(ACTIVE_STARTED, Live.started)
                .apply()
            context.startForegroundService(Intent(context, TrackService::class.java))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, TrackService::class.java).setAction(ACTION_STOP))
        }
    }
}
