package ch.geneve.slide.track

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import ch.geneve.slide.MainActivity
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Profile
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.TrackPhase
import kotlin.math.sqrt

/**
 * Keeps GPS, the barometer and the accelerometer running with the screen off, and shows the live speed in an
 * ongoing notification (the Android counterpart of the iOS Live Activity).
 */
class TrackService : Service(), SensorEventListener {
    private var location: LocationManager? = null
    private var sensors: SensorManager? = null
    private var listening = false
    private var pressureOrigin: Double? = null
    private var lastNotify = 0L
    private val listener = LocationListener { fix -> onFix(fix) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ch.geneve.slide.SlideApp.init(this)
        running = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Tracking.stop()
            return START_NOT_STICKY
        }
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTE_ID, note(), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTE_ID, note())
        }
        // Started again by Android after a kill: resume the same day, or stop if there is none.
        if (!Tracking.isActive && !Tracking.recoverActive()) {
            stopSelf()
            return START_NOT_STICKY
        }
        sync()
        return START_STICKY
    }

    /** Sensors run only while tracking, not while paused. */
    fun sync() {
        val want = Tracking.activity == Activity.TRACKING
        if (want && !listening) listen() else if (!want && listening) quiet()
        val power = getSystemService(PowerManager::class.java)
        Tracking.lowPower = power?.isPowerSaveMode == true
        notifyNow()
    }

    @SuppressLint("MissingPermission")
    private fun listen() {
        val lm = getSystemService(LocationManager::class.java)
        location = lm
        runCatching { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener) }
        val sm = getSystemService(SensorManager::class.java)
        sensors = sm
        pressureOrigin = null
        sm.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let { sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        listening = true
    }

    private fun quiet() {
        location?.removeUpdates(listener)
        sensors?.unregisterListener(this)
        listening = false
    }

    private fun onFix(fix: Location) {
        val vAcc = if (Build.VERSION.SDK_INT >= 26 && fix.hasVerticalAccuracy()) fix.verticalAccuracyMeters.toDouble() else null
        Tracking.onLocation(
            time = fix.time / 1000.0,
            lat = fix.latitude,
            lon = fix.longitude,
            gpsAltitude = fix.altitude,
            verticalAccuracy = vAcc,
            accuracy = if (fix.hasAccuracy()) fix.accuracy.toDouble() else 50.0,
            speed = if (fix.hasSpeed()) fix.speed.toDouble() else null,
        )
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_PRESSURE -> {
                val altitude = SensorManager.getAltitude(SensorManager.PRESSURE_STANDARD_ATMOSPHERE, event.values[0]).toDouble()
                val origin = pressureOrigin ?: altitude.also { pressureOrigin = it }
                Tracking.onRelativeAltitude(altitude - origin)
            }
            Sensor.TYPE_ACCELEROMETER -> {
                val (x, y, z) = Triple(event.values[0], event.values[1], event.values[2])
                val g = sqrt((x * x + y * y + z * z).toDouble()) / SensorManager.GRAVITY_EARTH
                Tracking.onAcceleration(event.timestamp / 1e9, g)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun notifyNow() {
        val now = SystemClock.elapsedRealtime()
        lastNotify = now
        getSystemService(NotificationManager::class.java).notify(NOTE_ID, note())
    }

    fun maybeNotify() {
        if (SystemClock.elapsedRealtime() - lastNotify >= 2000) notifyNow()
    }

    private fun note(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, L10n.t("android.notify.channel"), NotificationManager.IMPORTANCE_LOW),
        )
        val s = Tracking.summary
        val prefs = Profile.units
        val phase = when (Tracking.activity) {
            Activity.PAUSED -> L10n.t("tracking.phase.pause")
            Activity.IDLE -> L10n.t("tracking.phase.ready")
            Activity.TRACKING -> L10n.t(phaseKey(s.phase))
        }
        val speed = "${Fmt.speed(if (s.hasFix) s.speed else 0.0, prefs, L10n.frenchNumbers)} ${Fmt.speedUnit(prefs)}"
        val altitude = if (s.hasFix) Fmt.altitude(s.altitude, prefs, L10n.frenchNumbers) else "—"
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, TrackService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(speed)
            .setContentText("$phase · $altitude · ${Tracking.resort.ifBlank { L10n.t("tracking.live") }}")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(open)
            .addAction(0, L10n.t("tracking.stop"), stop)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
    }

    override fun onDestroy() {
        quiet()
        running = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "slide.track"
        private const val NOTE_ID = 7
        const val ACTION_STOP = "ch.geneve.slide.STOP"
        private var running: TrackService? = null

        fun phaseKey(phase: TrackPhase) = when (phase) {
            TrackPhase.UNKNOWN -> "tracking.phase.calibration"
            TrackPhase.SKIING -> "tracking.phase.skiing"
            TrackPhase.LIFT -> "tracking.phase.lift"
            TrackPhase.REST -> "tracking.phase.rest"
        }

        fun start(context: Context) {
            context.startForegroundService(Intent(context, TrackService::class.java))
        }

        fun refresh(context: Context) {
            running?.sync()
        }

        fun update(context: Context) {
            running?.maybeNotify()
        }

        fun stop(context: Context) {
            running?.let {
                it.stopForeground(STOP_FOREGROUND_REMOVE)
                it.stopSelf()
            }
        }
    }
}
