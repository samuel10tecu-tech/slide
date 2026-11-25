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
        Live.tracking = true
        listen()
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun listen() {
        val location = getSystemService(LocationManager::class.java)
        manager = location
        if (location.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            location.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 3f, listener)
        }
    }

    private fun onFix(location: Location) {
        val speed = if (location.hasSpeed()) location.speed.toDouble().coerceAtLeast(0.0) else 0.0
        val sample = Sample(location.time, location.latitude, location.longitude, location.altitude, speed)
        Live.samples.add(sample)
        Live.engine.add(sample)
        Live.speed = speed
        Live.phase = Live.engine.phase
        Coach.consider(this)
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
        save()
        super.onDestroy()
    }

    private fun save() {
        if (Live.samples.isEmpty()) return
        val lat = Live.samples.map { it.lat }.average()
        val lon = Live.samples.map { it.lon }.average()
        DayStore.save(this, DayFile(
            Live.id, Live.started, "", Live.engine.maxSpeed, Live.engine.distance, Live.engine.vertical,
            Live.engine.runs.toList(), lat, lon, Live.samples.toList()
        ))
    }

    companion object {
        const val ACTION_STOP = "ch.geneve.slide.STOP"
        fun start(context: Context) {
            Live.reset()
            context.startForegroundService(Intent(context, TrackService::class.java))
        }
        fun stop(context: Context) {
            context.startService(Intent(context, TrackService::class.java).setAction(ACTION_STOP))
        }
    }
}
