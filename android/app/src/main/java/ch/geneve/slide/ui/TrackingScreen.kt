package ch.geneve.slide.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.BatteryAlert
import androidx.compose.material.icons.filled.DownhillSkiing
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationSearching
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Profile
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.RunRecord
import ch.geneve.slide.logic.TrackSample
import ch.geneve.slide.logic.Units
import ch.geneve.slide.track.Activity
import ch.geneve.slide.track.TrackService
import ch.geneve.slide.track.Tracking
import kotlinx.coroutines.delay

@Composable
fun TrackingScreen(onFinished: () -> Unit) {
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    var now by remember { mutableDoubleStateOf(System.currentTimeMillis() / 1000.0) }
    var confirmStop by remember { mutableStateOf(false) }
    var settingsHint by remember { mutableStateOf(false) }
    var follow by remember { mutableStateOf(true) }
    var picked by remember { mutableStateOf<TrackSample?>(null) }
    val prefs = Profile.units
    val french = L10n.frenchNumbers
    val compact = LocalConfiguration.current.screenHeightDp < 600

    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis() / 1000.0
            delay(500)
        }
    }
    var lastRuns by remember { mutableStateOf(Tracking.summary.qualifiedRuns) }
    LaunchedEffect(Tracking.summary.qualifiedRuns) {
        if (Tracking.summary.qualifiedRuns > lastRuns) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        lastRuns = Tracking.summary.qualifiedRuns
    }

    fun begin() {
        val gps = context.getSystemService(LocationManager::class.java)
        if (gps?.isProviderEnabled(LocationManager.GPS_PROVIDER) != true) {
            Toast.makeText(context, L10n.t("android.gps.off"), Toast.LENGTH_LONG).show()
            context.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            return
        }
        Tracking.start()
    }

    val permissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
        if (granted[Manifest.permission.ACCESS_FINE_LOCATION] == true) begin() else settingsHint = true
    }

    fun requestStart() {
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val notes = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (fine && notes) {
            begin()
        } else {
            val asks = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Build.VERSION.SDK_INT >= 33) asks += Manifest.permission.POST_NOTIFICATIONS
            permissions.launch(asks.toTypedArray())
        }
    }

    val active = Tracking.activity != Activity.IDLE
    val preview = ch.geneve.slide.Preview.on
    Column(Modifier.fillMaxSize()) {
        if (active || preview) {
            Box(Modifier.fillMaxWidth().height(if (compact) 180.dp else 300.dp)) {
                TrackMap(if (preview && Tracking.mapSamples.isEmpty()) ch.geneve.slide.Preview.samples else Tracking.mapSamples, follow = follow && !preview, replay = null, dayMaxKmh = null, modifier = Modifier.fillMaxSize()) { picked = it }
                Column(Modifier.align(Alignment.BottomStart).padding(10.dp)) {
                    picked?.let {
                        Text(
                            "${Fmt.speed(it.speed, prefs, french)} ${Fmt.speedUnit(prefs)}", color = Color.White,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.background(Color.Black.copy(alpha = 0.55f), CircleShape).padding(horizontal = 10.dp, vertical = 6.dp),
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Row(
                            Modifier.background(Color.Black.copy(alpha = 0.55f), CircleShape).clickable { follow = !follow }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(if (follow) Icons.Default.NearMe else Icons.Default.MyLocation, null, tint = Color.White, modifier = Modifier.size(14.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(L10n.t(if (follow) "tracking.follow" else "tracking.recenter"), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(8.dp))
                        Text(L10n.t("tracking.map.offline"), color = Color.White.copy(alpha = 0.9f), fontSize = 10.sp, maxLines = 2,
                            modifier = Modifier.background(Color.Black.copy(alpha = 0.35f)).padding(2.dp))
                    }
                }
            }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().background(C.background).verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp).padding(top = if (active) 16.dp else 12.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Header()
            Gauge()
            val open = Tracking.summary.openRun
            if (open != null && Tracking.activity == Activity.TRACKING) OpenRunStrip(open)
            StatsGrid(if (Tracking.isActive) Tracking.duration(now) else 0.0)
            Notices(now)
            if (!active) {
                Text(L10n.t("tracking.intro"), color = C.muted, fontSize = 15.sp)
                Text(L10n.t(if (Tracking.usingBarometer) "tracking.baro.on" else "tracking.baro.off"), color = C.muted.copy(alpha = 0.9f), fontSize = 13.sp)
            }
            if (Tracking.recoverableId != null && !active) RecoveryCard()
        }
        Box(Modifier.background(C.background).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 6.dp)) {
            when (Tracking.activity) {
                Activity.IDLE -> BigButton(L10n.t("tracking.start"), Icons.Default.PlayArrow, C.accent) { requestStart() }
                Activity.TRACKING -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    BigButton(L10n.t("tracking.pause"), Icons.Default.Pause, C.surface2, C.text, Modifier.weight(1f)) {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        Tracking.pause()
                    }
                    BigButton(L10n.t("tracking.stop"), Icons.Default.Stop, C.danger, Color.White, Modifier.weight(1f)) { confirmStop = true }
                }
                Activity.PAUSED -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    BigButton(L10n.t("tracking.resume"), Icons.Default.PlayArrow, C.accent, modifier = Modifier.weight(1f)) {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        Tracking.resume()
                    }
                    BigButton(L10n.t("tracking.stop"), Icons.Default.Stop, C.danger, Color.White, Modifier.weight(1f)) { confirmStop = true }
                }
            }
        }
    }

    if (confirmStop) {
        AlertDialog(
            onDismissRequest = { confirmStop = false },
            title = { Text(L10n.t("tracking.stop.title")) },
            text = { Text(L10n.t("tracking.stop.message")) },
            confirmButton = {
                TextButton(onClick = {
                    confirmStop = false
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    Tracking.stop()
                    if (Tracking.lastArchive != null) onFinished()
                }) { Text(L10n.t("tracking.stop.confirm"), color = C.danger) }
            },
            dismissButton = { TextButton(onClick = { confirmStop = false }) { Text(L10n.t("tracking.stop.continue")) } },
            containerColor = C.surface,
        )
    }
    if (settingsHint) {
        AlertDialog(
            onDismissRequest = { settingsHint = false },
            title = { Text(L10n.t("tracking.settings.title")) },
            text = { Text(L10n.t("tracking.settings.message")) },
            confirmButton = {
                TextButton(onClick = {
                    settingsHint = false
                    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                }) { Text(L10n.t("tracking.settings.open")) }
            },
            dismissButton = { TextButton(onClick = { settingsHint = false }) { Text(L10n.t("tracking.settings.later")) } },
            containerColor = C.surface,
        )
    }
}

@Composable
private fun Header() {
    val title = if (Tracking.isActive) Tracking.resort.ifEmpty { L10n.t("tracking.live") }
    else Profile.homeMountain.trim().ifEmpty { L10n.t("tracking.ready") }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(L10n.t("tracking.brand"), color = C.accent, fontSize = 12.sp, fontWeight = FontWeight.Black, letterSpacing = 2.4.sp)
            Text(title, color = C.text, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
        }
        GpsPill()
    }
}

@Composable
private fun GpsPill() {
    val s = Tracking.summary
    val (title, color) = when {
        Tracking.activity != Activity.TRACKING -> L10n.t("tracking.gps") to C.muted
        !s.hasFix || s.accuracy < 0 -> L10n.t("tracking.gps.search") to C.orange
        s.accuracy <= 8 -> L10n.t("tracking.gps.good") to C.accent
        s.accuracy <= 20 -> L10n.t("tracking.gps.ok") to C.ice
        else -> L10n.t("tracking.gps.weak") to C.orange
    }
    Text(
        title, color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.background(color.copy(alpha = 0.15f), CircleShape).padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun Gauge() {
    val s = Tracking.summary
    val prefs = Profile.units
    val preview = ch.geneve.slide.Preview.on && Tracking.activity != Activity.TRACKING
    val speed = (if (s.hasFix) s.speed else 0.0) + if (preview) 67.4 / 3.6 else 0.0
    val tint = if ((Tracking.activity == Activity.TRACKING && s.hasFix) || preview) C.speed(speed) else C.snow
    val (phaseTitle, phaseColor) = when (Tracking.activity) {
        Activity.IDLE -> L10n.t("tracking.phase.ready") to C.muted
        Activity.PAUSED -> L10n.t("tracking.phase.pause") to C.orange
        Activity.TRACKING -> L10n.t(TrackService.phaseKey(s.phase)) to C.phase(s.phase)
    }
    val size = if (Tracking.activity == Activity.IDLE) 230.dp else 300.dp
    Column(
        Modifier.fillMaxWidth()
            .background(Brush.radialGradient(listOf(tint.copy(alpha = 0.22f), Color.Transparent), radius = 500f))
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        PhaseBadge(phaseTitle, phaseColor, pulsing = Tracking.activity == Activity.TRACKING && s.phase == ch.geneve.slide.logic.TrackPhase.SKIING)
        Spacer(Modifier.height(6.dp))
        SpeedGauge(
            Fmt.speed(speed, prefs, L10n.frenchNumbers), Fmt.speedUnit(prefs), Units.kmh(speed) / 100, tint,
            Modifier.size(size),
        )
    }
}

@Composable
private fun OpenRunStrip(run: RunRecord) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    val title = if (Tracking.summary.qualifiedRuns == run.index) L10n.t("tracking.run.named", run.index) else L10n.t("tracking.run.current")
    Column(Modifier.fillMaxWidth().card(C.accent.copy(alpha = 0.12f), 16).padding(14.dp)) {
        Text(title, color = C.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        Text(
            "${Fmt.distance(run.distance, prefs, f)} · ${Fmt.altitude(run.verticalDrop, prefs, f)} · max ${Fmt.speed(run.maxSpeed, prefs, f)}",
            color = C.muted, fontSize = 13.sp,
        )
    }
}

@Composable
private fun StatsGrid(duration: Double) {
    val s = Tracking.summary
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    val tiles = listOf(
        Triple(L10n.t("tracking.stat.max"), Fmt.speed(s.maxSpeed, prefs, f), Icons.Default.Flag),
        Triple(L10n.t("tracking.stat.distance"), Fmt.distance(s.distance, prefs, f), Icons.Default.Straighten),
        Triple(L10n.t("tracking.stat.vertical"), Fmt.altitude(s.vertical, prefs, f), Icons.Default.ArrowDownward),
        Triple(L10n.t("tracking.stat.altitude"), if (s.hasFix) Fmt.altitude(s.altitude, prefs, f) else "—", Icons.Default.Landscape),
        Triple(L10n.t("tracking.stat.duration"), Fmt.duration(duration), Icons.Default.Timer),
        Triple(L10n.t("tracking.stat.runs"), "${s.qualifiedRuns}", Icons.Default.DownhillSkiing),
    )
    Grid(tiles) { (label, value, icon), modifier -> StatTile(label, value, icon, modifier) }
}

/** Two columns, like LazyVGrid with two flexible items. */
@Composable
fun <T> Grid(items: List<T>, cell: @Composable (T, Modifier) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { cell(it, Modifier.weight(1f)) }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Notices(now: Double) {
    val s = Tracking.summary
    if (Tracking.lowPower && Tracking.isActive) Banner(L10n.t("tracking.banner.lowpower"), Icons.Default.BatteryAlert, C.orange)
    val fix = Tracking.lastFixAt
    if (Tracking.activity == Activity.TRACKING && fix != null && now - fix > 8) {
        Banner(L10n.t("tracking.banner.stale"), Icons.Default.LocationOff, C.orange)
    } else if (Tracking.activity == Activity.TRACKING && s.accuracy > 25) {
        Banner(L10n.t("tracking.banner.accuracy", s.accuracy.toInt()), Icons.Default.LocationSearching, C.ice)
    }
}

@Composable
private fun RecoveryCard() {
    Column(Modifier.fillMaxWidth().card().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(L10n.t("tracking.recovery.title"), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        Text(Tracking.recoverableTitle, color = C.muted, fontSize = 15.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                L10n.t("tracking.resume"), color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 17.sp,
                modifier = Modifier.background(C.accent, CircleShape).clickable { Tracking.resumeRecovered() }.padding(horizontal = 16.dp, vertical = 10.dp),
            )
            Text(
                L10n.t("tracking.recovery.close"), color = C.text, fontWeight = FontWeight.Bold, fontSize = 17.sp,
                modifier = Modifier.background(C.surface2, CircleShape).clickable { Tracking.closeRecovered() }.padding(horizontal = 16.dp, vertical = 10.dp),
            )
        }
    }
}
