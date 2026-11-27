package ch.geneve.slide.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import ch.geneve.slide.logic.Geo
import ch.geneve.slide.logic.SpeedPaint
import ch.geneve.slide.logic.TrackSample
import org.osmdroid.events.MapEventsReceiver
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.MapEventsOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import kotlin.math.max

object TrackGeometry {
    /** At most [limit] points, evenly picked, always keeping the last one. */
    fun simplify(samples: List<TrackSample>, limit: Int = 700): List<TrackSample> {
        if (samples.size <= limit) return samples
        val step = (samples.size - 1).toDouble() / (limit - 1)
        return (0 until limit).map { samples[minOf(samples.size - 1, Math.round(it * step).toInt())] }
    }

    /**
     * One line per run of similar speed, so the track shows the speed colours without thousands of overlays.
     * The line is cut where the GPS had a gap.
     */
    fun gradientLines(samples: List<TrackSample>, dayMaxKmh: Double?, width: Float, onTap: (() -> Unit)? = null): List<Polyline> {
        val lines = mutableListOf<Polyline>()
        var points = mutableListOf<GeoPoint>()
        var color = 0
        fun close() {
            if (points.size >= 2) {
                lines += Polyline().apply {
                    setPoints(points)
                    outlinePaint.color = color
                    outlinePaint.strokeWidth = width
                    outlinePaint.strokeCap = Paint.Cap.ROUND
                    outlinePaint.strokeJoin = Paint.Join.ROUND
                    outlinePaint.isAntiAlias = true
                    isGeodesic = false
                    if (onTap != null) setOnClickListener { _, _, _ -> onTap(); true } else setOnClickListener { _, _, _ -> false }
                }
            }
        }
        for (index in 1 until samples.size) {
            val a = samples[index - 1]
            val b = samples[index]
            if (b.time - a.time > 45) {
                close()
                points = mutableListOf()
                continue
            }
            val segment = SpeedPaint.argb(quantize(b.speed), dayMaxKmh)
            if (points.isEmpty()) {
                color = segment
                points.add(GeoPoint(a.latitude, a.longitude))
            } else if (segment != color) {
                val last = points.last()
                close()
                points = mutableListOf(last)
                color = segment
            }
            points.add(GeoPoint(b.latitude, b.longitude))
        }
        close()
        return lines
    }

    /** Groups colours by 3 km/h so neighbouring points share a line. */
    private fun quantize(mps: Double) = Math.round(mps * 3.6 / 3.0) * 3.0 / 3.6

    fun bounds(samples: List<TrackSample>): BoundingBox? {
        if (samples.size < 2) return null
        val north = samples.maxOf { it.latitude }
        val south = samples.minOf { it.latitude }
        val east = samples.maxOf { it.longitude }
        val west = samples.minOf { it.longitude }
        val pad = max(0.002, max(north - south, east - west) * 0.15)
        return BoundingBox(north + pad, east + pad, south - pad, west - pad)
    }
}

fun newMapView(context: Context): MapView = MapView(context).apply {
    setTileSource(TileSourceFactory.MAPNIK)
    setMultiTouchControls(true)
    zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
    isTilesScaledToDpi = true
    minZoomLevel = 3.0
    maxZoomLevel = 19.0
    controller.setZoom(15.0)
}

@Composable
fun OsmAttribution(modifier: Modifier = Modifier) {
    Text(
        "© OpenStreetMap", color = Color.Black.copy(alpha = 0.7f), fontSize = 9.sp,
        modifier = modifier.padding(4.dp),
    )
}

/** Live or replay map of one day, with the track coloured by speed (iOS LiveTrackMap). */
@Composable
fun TrackMap(
    samples: List<TrackSample>,
    follow: Boolean,
    replay: TrackSample?,
    dayMaxKmh: Double?,
    modifier: Modifier = Modifier,
    onSelect: ((TrackSample) -> Unit)? = null,
) {
    val context = LocalContext.current
    val state = remember { MapState() }
    val map = remember { newMapView(context) }
    DisposableEffect(Unit) {
        map.onResume()
        onDispose { map.onPause(); map.onDetach() }
    }
    Box(modifier) {
        AndroidView(factory = { map }, update = { view ->
            state.samples = samples
            val signature = "${samples.size}|${samples.lastOrNull()?.time}|$dayMaxKmh"
            if (signature != state.signature) {
                state.signature = signature
                view.overlays.removeAll { it is Polyline }
                val lines = TrackGeometry.gradientLines(TrackGeometry.simplify(samples, 1500), dayMaxKmh, 9f * view.resources.displayMetrics.density)
                view.overlays.addAll(0, lines)
                if (!state.fitted && !follow) {
                    TrackGeometry.bounds(samples)?.let { box ->
                        state.fitted = true
                        view.post { view.zoomToBoundingBox(box, false) }
                    }
                }
            }
            if (onSelect != null && state.tapper == null) {
                val tapper = MapEventsOverlay(object : MapEventsReceiver {
                    override fun singleTapConfirmedHelper(p: GeoPoint): Boolean {
                        val nearest = state.samples.minByOrNull { Geo.haversineMeters(it.latitude, it.longitude, p.latitude, p.longitude) } ?: return false
                        val meters = Geo.haversineMeters(nearest.latitude, nearest.longitude, p.latitude, p.longitude)
                        val metersPerPixel = view.projection.metersToPixels(1f).let { if (it > 0) 1 / it else 1f }
                        if (meters <= 40 * metersPerPixel * view.resources.displayMetrics.density) onSelect(nearest)
                        return true
                    }
                    override fun longPressHelper(p: GeoPoint) = false
                })
                state.tapper = tapper
                view.overlays.add(tapper)
            }
            val dot = replay ?: if (follow) samples.lastOrNull() else null
            if (dot != null) {
                val marker = state.marker ?: Marker(view).also {
                    it.icon = dotIcon(view.context, if (replay != null) C.snow else C.accent)
                    it.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    it.setInfoWindow(null)
                    state.marker = it
                    view.overlays.add(it)
                }
                marker.position = GeoPoint(dot.latitude, dot.longitude)
                if (follow) view.controller.animateTo(marker.position)
            } else {
                state.marker?.let { view.overlays.remove(it) }
                state.marker = null
            }
            view.invalidate()
        }, modifier = Modifier.fillMaxSize())
        OsmAttribution(Modifier.align(Alignment.BottomEnd))
    }
}

private class MapState {
    var signature = ""
    var fitted = false
    var marker: Marker? = null
    var tapper: MapEventsOverlay? = null
    var samples: List<TrackSample> = emptyList()
}

fun dotIcon(context: Context, color: Color): BitmapDrawable {
    val density = context.resources.displayMetrics.density
    val size = (20 * density).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
    paint.color = android.graphics.Color.argb((color.alpha * 255).toInt(), (color.red * 255).toInt(), (color.green * 255).toInt(), (color.blue * 255).toInt())
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - 3 * density, paint)
    return BitmapDrawable(context.resources, bitmap)
}

/** Round pin with a count, or a ▲ for one day (iOS DayPin). */
fun pinIcon(context: Context, count: Int): BitmapDrawable {
    val density = context.resources.displayMetrics.density
    val size = ((if (count > 1) 36 else 26) * density).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.argb(230, 8, 20, 36) }
    val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.rgb(126, 231, 255)
        style = Paint.Style.STROKE
        strokeWidth = 2 * density
    }
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - density, fill)
    canvas.drawCircle(size / 2f, size / 2f, size / 2f - density, ring)
    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.rgb(126, 231, 255)
        textAlign = Paint.Align.CENTER
        textSize = (if (count > 1) 15 else 12) * density
        isFakeBoldText = true
    }
    canvas.drawText(if (count > 1) "$count" else "▲", size / 2f, size / 2f - (text.descent() + text.ascent()) / 2, text)
    return BitmapDrawable(context.resources, bitmap)
}

data class DrawnTrack(val id: String, val samples: List<TrackSample>, val latitude: Double, val longitude: Double, val dayMaxKmh: Double?)

data class PlaceCluster(val latitude: Double, val longitude: Double, val dayIds: List<String>)

object PlaceIndex {
    fun clusters(tracks: List<DrawnTrack>, radiusMeters: Double = 8_000.0): List<PlaceCluster> {
        val groups = mutableListOf<MutableList<DrawnTrack>>()
        for (track in tracks) {
            val group = groups.firstOrNull { g -> g.any { Geo.haversineMeters(it.latitude, it.longitude, track.latitude, track.longitude) <= radiusMeters } }
            if (group != null) group.add(track) else groups.add(mutableListOf(track))
        }
        return groups.map { g -> PlaceCluster(g.sumOf { it.latitude } / g.size, g.sumOf { it.longitude } / g.size, g.map { it.id }) }
    }
}

/** Every saved day: speed-coloured tracks when zoomed in, pins grouped by place when zoomed out (iOS WorldTracksMap). */
@Composable
fun WorldMap(tracks: List<DrawnTrack>, modifier: Modifier, onOpen: (String) -> Unit, onGroup: (PlaceCluster) -> Unit) {
    val context = LocalContext.current
    val map = remember { newMapView(context) }
    val state = remember { MapState() }
    DisposableEffect(Unit) {
        map.onResume()
        onDispose { map.onPause(); map.onDetach() }
    }
    fun draw(view: MapView) {
        val far = view.zoomLevelDouble < 10.5
        val signature = tracks.joinToString(",") { it.id } + if (far) "|far" else "|near"
        android.util.Log.i("SlideMap", "draw tracks=${tracks.size} zoom=${view.zoomLevelDouble} far=$far same=${signature == state.signature} size=${view.width}x${view.height} center=${view.mapCenter}")
        if (signature == state.signature) return
        state.signature = signature
        view.overlays.clear()
        if (far) {
            for (cluster in PlaceIndex.clusters(tracks)) {
                view.overlays.add(Marker(view).apply {
                    position = GeoPoint(cluster.latitude, cluster.longitude)
                    icon = pinIcon(view.context, cluster.dayIds.size)
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    setInfoWindow(null)
                    setOnMarkerClickListener { _, _ ->
                        if (cluster.dayIds.size == 1) onOpen(cluster.dayIds.first()) else onGroup(cluster)
                        true
                    }
                })
            }
        } else {
            val width = 6f * view.resources.displayMetrics.density
            for (track in tracks) view.overlays.addAll(TrackGeometry.gradientLines(track.samples, track.dayMaxKmh, width) { onOpen(track.id) })
        }
        view.invalidate()
    }
    Box(modifier) {
        AndroidView(factory = {
            map.apply {
                addMapListener(org.osmdroid.events.DelayedMapListener(object : MapListener {
                    override fun onScroll(event: ScrollEvent?): Boolean {
                        draw(this@apply)
                        return false
                    }
                    override fun onZoom(event: ZoomEvent?): Boolean {
                        draw(this@apply)
                        return false
                    }
                }, 150))
            }
        }, update = { view ->
            if (!state.fitted && tracks.isNotEmpty()) {
                state.fitted = true
                val box = TrackGeometry.bounds(tracks.flatMap { it.samples })
                // Fit once the view has its size, then draw for the new zoom (tracks near, pins far).
                view.post {
                    if (box != null) view.zoomToBoundingBox(box, false)
                    state.signature = ""
                    draw(view)
                }
            } else if (tracks.isEmpty() && !state.fitted) {
                view.controller.setZoom(6.0)
                view.controller.setCenter(GeoPoint(46.2, 7.5))
            }
            draw(view)
        }, modifier = Modifier.fillMaxSize())
        OsmAttribution(Modifier.align(Alignment.BottomEnd))
    }
}
