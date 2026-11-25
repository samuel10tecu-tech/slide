package ch.geneve.slide

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.School
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import java.io.File
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    private val permission = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
        if (granted[Manifest.permission.ACCESS_FINE_LOCATION] == true) TrackService.start(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Configuration.getInstance().userAgentValue = packageName
        when (intent?.action) {
            "ch.geneve.slide.SPEAK_MAX" -> Coach.speak(this, "${getString(R.string.max_today)} ${"%.0f".format(Coach.todayMax(this) * 3.6)} km/h", true)
            "ch.geneve.slide.SPEAK_DISTANCE" -> Coach.speak(this, "${getString(R.string.distance_today)} ${"%.1f".format(Coach.todayDistance(this) / 1000)} km", true)
        }
        setContent { SlideApp(::startRide) }
    }

    private fun startRide() {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val note = if (android.os.Build.VERSION.SDK_INT >= 33) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true
        if (fine && note) TrackService.start(this) else {
            val asks = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
            if (android.os.Build.VERSION.SDK_INT >= 33) asks += Manifest.permission.POST_NOTIFICATIONS
            permission.launch(asks.toTypedArray())
        }
    }
}

private val Night = Color(0xFF071526)
private val Card = Color(0xFF0E2436)
private val Glacier = Color(0xFF7EE7FF)
private val Snow = Color(0xFFF7FBFF)

@Composable
private fun SlideApp(onStart: () -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    val titles = listOf(R.string.track, R.string.map, R.string.history, R.string.learn, R.string.profile)
    Scaffold(
        containerColor = Night,
        bottomBar = {
            NavigationBar(containerColor = Card) {
                titles.forEachIndexed { index, title ->
                    NavigationBarItem(
                        selected = tab == index,
                        onClick = { tab = index },
                        icon = {
                            Icon(
                                when (index) {
                                    1 -> Icons.Default.Map
                                    2 -> Icons.Default.History
                                    3 -> Icons.Default.School
                                    4 -> Icons.Default.Person
                                    else -> Icons.Default.PlayArrow
                                },
                                null
                            )
                        },
                        label = { Text(androidx.compose.ui.res.stringResource(title)) }
                    )
                }
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().background(Night).padding(padding).padding(16.dp)) {
            when (tab) {
                0 -> TrackScreen(onStart)
                1 -> SpotScreen()
                2 -> HistoryScreen()
                3 -> LearnScreen()
                else -> ProfileScreen()
            }
        }
    }
}

@Composable
private fun TrackScreen(onStart: () -> Unit) {
    val context = LocalContext.current
    var tick by remember { mutableIntStateOf(0) }
    androidx.compose.runtime.LaunchedEffect(Live.tracking) {
        while (true) {
            kotlinx.coroutines.delay(500)
            tick++
        }
    }
    Column(Modifier.fillMaxSize()) {
        Text(if (Live.tracking) context.getString(R.string.live) else context.getString(R.string.ready), color = Glacier, fontWeight = FontWeight.Bold)
        Text("${"%.1f".format(Live.speed * 3.6)}", color = Snow, fontSize = 72.sp, fontWeight = FontWeight.Black)
        Text(context.getString(R.string.kmh), color = Snow)
        Text("${context.getString(R.string.runs)} ${Live.engine.runs.size} · ${"%.1f".format(Live.engine.distance / 1000)} km · ${Live.engine.vertical.roundToInt()} m", color = Snow)
        if (Live.samples.size > 1) OsmMap(Live.samples.map { GeoPoint(it.lat, it.lon) }, emptyList(), Modifier.fillMaxWidth().height(280.dp))
        Button(onClick = {
            if (Live.tracking) TrackService.stop(context) else onStart()
        }) { Text(if (Live.tracking) context.getString(R.string.stop) else context.getString(R.string.start)) }
    }
}

private fun Modifier.weightMissing() = this.then(Modifier.fillMaxWidth())

@Composable
private fun OsmMap(line: List<GeoPoint>, pins: List<GeoPoint>, modifier: Modifier) {
    AndroidView(modifier = modifier.fillMaxWidth().padding(vertical = 8.dp), factory = { ctx ->
        MapView(ctx).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            controller.setZoom(14.0)
        }
    }, update = { map ->
        map.overlays.clear()
        if (line.size > 1) {
            map.overlays.add(Polyline().apply { setPoints(line); outlinePaint.color = android.graphics.Color.parseColor("#7EE7FF"); outlinePaint.strokeWidth = 8f })
            map.controller.setCenter(line.last())
        }
        pins.forEach { point ->
            map.overlays.add(Marker(map).apply { position = point; setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM) })
        }
        if (line.isEmpty() && pins.isNotEmpty()) map.controller.setCenter(pins.first())
        map.invalidate()
    })
}

@Composable
private fun SpotScreen() {
    val context = LocalContext.current
    val days = remember { DayStore.load(context) }
    if (days.isEmpty()) Text(context.getString(R.string.spots_empty), color = Snow)
    OsmMap(emptyList(), days.map { GeoPoint(it.lat, it.lon) }, Modifier.fillMaxWidth().height(480.dp))
}

@Composable
private fun HistoryScreen() {
    val context = LocalContext.current
    val days = remember { DayStore.load(context) }
    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (days.isEmpty()) Text(context.getString(R.string.no_days), color = Snow)
        days.forEach { day ->
            Column(Modifier.fillMaxWidth().background(Card).padding(12.dp)) {
                Text("${"%.0f".format(day.max * 3.6)} km/h", color = Snow, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text("${"%.1f".format(day.distance / 1000)} km · ${day.vertical.roundToInt()} m · ${day.runs.size}", color = Glacier)
                day.runs.forEach { run ->
                    Text("${run.index}  ${"%.1f".format(run.distance / 1000)} km  ${"%.0f".format(run.max * 3.6)}", color = Snow)
                }
                Button(onClick = share(context, day)) { Text(context.getString(R.string.share_gpx)) }
            }
        }
    }
}

private fun share(context: android.content.Context, day: DayFile): () -> Unit = {
    val file = File(context.cacheDir, "slide.gpx")
    file.writeText(DayStore.gpx(day))
    val uri = FileProvider.getUriForFile(context, "ch.geneve.slide.files", file)
    val send = Intent(Intent.ACTION_SEND).setType("application/gpx+xml").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    context.startActivity(Intent.createChooser(send, "GPX"))
}

@Composable
private fun LearnScreen() {
    val context = LocalContext.current
    val tricks = listOf(
        Triple(R.string.beginner, "Ollie", false),
        Triple(R.string.park, "360", false),
        Triple(R.string.advanced, "Backflip", true)
    )
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        tricks.forEach { (level, name, coach) ->
            Column(Modifier.fillMaxWidth().background(Card).padding(12.dp)) {
                Text(context.getString(level), color = Glacier, fontWeight = FontWeight.Bold)
                Text(name, color = Snow, fontSize = 22.sp)
                if (coach) Text(context.getString(R.string.coach), color = Color(0xFFFF4D5E))
                Button(onClick = {
                    val query = Uri.encode("ski $name tutorial")
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=$query")))
                }) { Text(context.getString(R.string.watch)) }
            }
        }
    }
}

@Composable
private fun ProfileScreen() {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("slide", android.content.Context.MODE_PRIVATE)
    var on by remember { mutableStateOf(prefs.getBoolean("audio", false)) }
    var threshold by remember { mutableStateOf(prefs.getFloat("threshold", 60f)) }
    var every by remember { mutableStateOf(prefs.getFloat("every", 1f)) }
    var period by remember { mutableStateOf(prefs.getInt("period", 0).toFloat()) }
    Column(Modifier.verticalScroll(rememberScrollState())) {
        Text(context.getString(R.string.audio), color = Snow, fontWeight = FontWeight.Bold, fontSize = 22.sp)
        Text(context.getString(R.string.audio_detail), color = Glacier)
        Row { Text(context.getString(R.string.audio), color = Snow); Switch(checked = on, onCheckedChange = { on = it; prefs.edit().putBoolean("audio", it).apply() }) }
        Text("${context.getString(R.string.threshold)} ${threshold.roundToInt()} km/h", color = Snow)
        Slider(value = threshold, onValueChange = { threshold = it; prefs.edit().putFloat("threshold", it).apply() }, valueRange = 20f..130f, steps = 21)
        Text("${context.getString(R.string.every_km)} ${"%.1f".format(every)} km", color = Snow)
        Slider(value = every, onValueChange = { every = (it * 2).roundToInt() / 2f; prefs.edit().putFloat("every", every).apply() }, valueRange = 0.5f..10f)
        Text(if (period < 1) context.getString(R.string.off) else "${period.roundToInt()} min", color = Snow)
        Slider(value = period, onValueChange = { period = it; prefs.edit().putInt("period", it.roundToInt()).apply() }, valueRange = 0f..30f, steps = 29)
        Button(onClick = { Coach.test(context) }) { Text(context.getString(R.string.test_voice)) }
    }
}
