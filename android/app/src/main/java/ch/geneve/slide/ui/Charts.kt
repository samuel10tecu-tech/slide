package ch.geneve.slide.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ch.geneve.slide.logic.RunRecord
import ch.geneve.slide.logic.SpeedPaint
import ch.geneve.slide.logic.TrackSample
import ch.geneve.slide.logic.UnitPrefs
import ch.geneve.slide.logic.Units
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

private fun downsample(samples: List<TrackSample>, maxCount: Int = 280) = TrackGeometry.simplify(samples, maxCount)

/** Speed line in the speed colours, then altitude as a filled area (iOS SpeedAltitudeChart). */
@Composable
fun SpeedAltitudeChart(samples: List<TrackSample>, prefs: UnitPrefs, speedTitle: String, altitudeTitle: String) {
    val rows = remember(samples) { downsample(samples) }
    val speeds = rows.map { if (prefs.speedMetric) Units.kmh(it.speed) else Units.mph(it.speed) }
    val altitudes = rows.map { if (prefs.altitudeMetric) it.rawAltitude else Units.feet(it.rawAltitude) }
    Column {
        SectionTitle(speedTitle)
        Spacer(Modifier.height(10.dp))
        LineChart(
            values = speeds, floor = 0.0, height = 160,
            stroke = Brush.verticalGradient(SpeedPaint.stops.reversed().map { Color(0xFF000000.toInt() or it.second) }),
            fill = null,
        )
        Spacer(Modifier.height(14.dp))
        SectionTitle(altitudeTitle)
        Spacer(Modifier.height(10.dp))
        LineChart(values = altitudes, floor = null, height = 140, stroke = Brush.linearGradient(listOf(C.ice, C.ice)), fill = C.ice.copy(alpha = 0.25f))
    }
}

@Composable
private fun LineChart(values: List<Double>, floor: Double?, height: Int, stroke: Brush, fill: Color?) {
    if (values.size < 2) return
    val rawMin = floor ?: values.min()
    val rawMax = values.max()
    val step = niceStep(rawMax - rawMin)
    val low = floor(rawMin / step) * step
    val high = max(low + step, ceil(rawMax / step) * step)
    Row(Modifier.fillMaxWidth().height(height.dp)) {
        Column(Modifier.fillMaxHeight().width(44.dp)) {
            Text(label(high), color = C.muted, fontSize = 10.sp)
            Spacer(Modifier.weight(1f))
            Text(label((high + low) / 2), color = C.muted, fontSize = 10.sp)
            Spacer(Modifier.weight(1f))
            Text(label(low), color = C.muted, fontSize = 10.sp)
        }
        Canvas(Modifier.weight(1f).fillMaxHeight()) {
            val grid = Color.White.copy(alpha = 0.1f)
            for (i in 0..2) {
                val y = size.height * i / 2f
                drawLine(grid, Offset(0f, y), Offset(size.width, y), 1.dp.toPx())
            }
            fun point(i: Int): Offset {
                val x = size.width * i / (values.size - 1)
                val y = size.height * (1 - ((values[i] - low) / (high - low))).toFloat()
                return Offset(x, y)
            }
            val line = Path().apply {
                moveTo(point(0).x, point(0).y)
                for (i in 1 until values.size) {
                    val previous = point(i - 1)
                    val current = point(i)
                    val midX = (previous.x + current.x) / 2
                    cubicTo(midX, previous.y, midX, current.y, current.x, current.y)
                }
            }
            if (fill != null) {
                val area = Path().apply {
                    addPath(line)
                    lineTo(size.width, size.height)
                    lineTo(0f, size.height)
                    close()
                }
                drawPath(area, fill)
            }
            drawPath(line, stroke, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}

private fun niceStep(span: Double): Double {
    val raw = max(span, 1.0) / 2
    val magnitude = Math.pow(10.0, floor(Math.log10(raw)))
    val normalized = raw / magnitude
    return magnitude * when {
        normalized <= 1 -> 1.0
        normalized <= 2 -> 2.0
        normalized <= 5 -> 5.0
        else -> 10.0
    }
}

private fun label(value: Double) = if (value >= 100 || value == floor(value)) value.toInt().toString() else "%.1f".format(value)

/** One bar per run, coloured by its top speed (iOS RunBarChart). */
@Composable
fun RunBarChart(runs: List<RunRecord>, prefs: UnitPrefs, title: String) {
    Column {
        SectionTitle(title)
        Spacer(Modifier.height(8.dp))
        if (runs.isEmpty()) {
            Text("—", color = C.muted)
            return@Column
        }
        val values = runs.map { if (prefs.speedMetric) Units.kmh(it.maxSpeed) else Units.mph(it.maxSpeed) }
        val step = niceStep(values.max())
        val high = max(step, ceil(values.max() / step) * step)
        Row(Modifier.fillMaxWidth().height(160.dp)) {
            Column(Modifier.fillMaxHeight().width(44.dp)) {
                Text(label(high), color = C.muted, fontSize = 10.sp)
                Spacer(Modifier.weight(1f))
                Text(label(high / 2), color = C.muted, fontSize = 10.sp)
                Spacer(Modifier.weight(1f))
                Text("0", color = C.muted, fontSize = 10.sp)
            }
            Canvas(Modifier.weight(1f).fillMaxHeight()) {
                val slot = size.width / runs.size
                val barWidth = slot * 0.62f
                runs.forEachIndexed { i, run ->
                    val h = (size.height * values[i] / high).toFloat()
                    drawRoundRect(
                        C.bandFor(run.maxSpeed),
                        topLeft = Offset(slot * i + (slot - barWidth) / 2, size.height - h),
                        size = Size(barWidth, h),
                        cornerRadius = CornerRadius(6.dp.toPx()),
                    )
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = 44.dp)) {
            runs.forEach { run ->
                Text("${run.index}", color = C.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}
