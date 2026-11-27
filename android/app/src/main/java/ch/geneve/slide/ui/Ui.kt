package ch.geneve.slide.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ch.geneve.slide.logic.SpeedBand
import ch.geneve.slide.logic.SpeedPaint
import ch.geneve.slide.logic.TrackPhase
import ch.geneve.slide.logic.Trick

/** Colours of the iOS Theme. */
object C {
    val background = Color(0xFF071526)
    val surface = Color(0xFF0E2436)
    val surface2 = Color(0xFF16344A)
    val accent = Color(0xFF7EE7FF)
    val ice = Color(0xFFB9F3FF)
    val snow = Color(0xFFF7FBFF)
    val text = Color(0xFFF7FBFF)
    val muted = Color(0xFFC5D4E4)
    val danger = Color(0xFFFF5A6A)
    val orange = Color(0xFFFFB15A)
    val pink = Color(0xFFFF8AD4)
    val pisteGreen = Color(0xFF3DDC6A)
    val pisteBlue = Color(0xFF4C8DFF)
    val pisteRed = Color(0xFFFF4D5E)
    val ink = Color(0xFF071526)

    fun speed(mps: Double, dayMaxKmh: Double? = null) = Color(SpeedPaint.argb(mps, dayMaxKmh))

    fun band(band: SpeedBand) = when (band) {
        SpeedBand.SLOW -> Color(0xFF3B82F6)
        SpeedBand.CRUISE -> Color(0xFF3DDC6A)
        SpeedBand.FAST -> Color(0xFFFFE14A)
        SpeedBand.FLYING -> Color(0xFFFF9A2E)
        SpeedBand.EXTREME -> Color(0xFFE23BFF)
    }

    fun bandFor(mps: Double) = band(SpeedBand.forSpeed(mps))

    fun phase(phase: TrackPhase) = when (phase) {
        TrackPhase.SKIING -> accent
        TrackPhase.LIFT -> ice
        else -> muted
    }

    fun level(level: Trick.Level) = when (level) {
        Trick.Level.DEBUTANT -> pisteGreen
        Trick.Level.INTERMEDIAIRE -> pisteBlue
        Trick.Level.AVANCE -> pisteRed
        Trick.Level.EXPERT -> snow
    }
}

@Composable
fun SlideTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = C.accent, onPrimary = C.ink, background = C.background, onBackground = C.text,
            surface = C.surface, onSurface = C.text, surfaceVariant = C.surface2, onSurfaceVariant = C.muted,
            secondaryContainer = C.surface2, onSecondaryContainer = C.accent, error = C.danger,
        ),
        content = content,
    )
}

fun Modifier.card(color: Color = C.surface, radius: Int = 18) =
    this.clip(RoundedCornerShape(radius.dp)).background(color)

/** Night gradient with two mountain silhouettes, like the iOS ScreenBackground. */
@Composable
fun ScreenBackground(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.verticalGradient(listOf(Color(0xFF071526), Color(0xFF0C2A40), Color(0xFF12344C))))
            fun mountains(height: Float, offset: Float): Path {
                val w = size.width
                val top = size.height - height + offset
                return Path().apply {
                    moveTo(0f, size.height)
                    lineTo(0f, top + height * 0.78f)
                    lineTo(w * 0.16f, top + height * 0.46f)
                    lineTo(w * 0.28f, top + height * 0.62f)
                    lineTo(w * 0.48f, top + height * 0.18f)
                    lineTo(w * 0.64f, top + height * 0.55f)
                    lineTo(w * 0.8f, top + height * 0.32f)
                    lineTo(w, top + height * 0.7f)
                    lineTo(w, size.height)
                    close()
                }
            }
            drawPath(mountains(220.dp.toPx(), 0f), Color.White.copy(alpha = 0.07f))
            drawPath(
                mountains(150.dp.toPx(), 18.dp.toPx()),
                Brush.verticalGradient(
                    listOf(Color.White.copy(alpha = 0.16f), Color.White.copy(alpha = 0.02f)),
                    startY = size.height - 150.dp.toPx(), endY = size.height,
                ),
            )
        }
        content()
    }
}

@Composable
fun BigButton(title: String, icon: ImageVector, fill: Color, foreground: Color = Color.Black, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().height(70.dp).clip(RoundedCornerShape(22.dp)).background(fill).clickable(onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = foreground)
        Spacer(Modifier.width(10.dp))
        Text(title, color = foreground, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun StatTile(label: String, value: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Column(modifier.card().padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = C.muted, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(label, color = C.muted, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.height(6.dp))
        AutoText(value, 26.sp, FontWeight.Bold, C.text)
    }
}

/** One line that shrinks instead of wrapping (iOS minimumScaleFactor). */
@Composable
fun AutoText(text: String, size: TextUnit, weight: FontWeight, color: Color, modifier: Modifier = Modifier) {
    val scale = when {
        text.length > 12 -> 0.6f
        text.length > 9 -> 0.8f
        else -> 1f
    }
    Text(
        text, modifier = modifier, color = color, maxLines = 1, overflow = TextOverflow.Clip,
        style = TextStyle(fontSize = size * scale, fontWeight = weight, fontFeatureSettings = "tnum"),
    )
}

@Composable
fun PhaseBadge(title: String, color: Color, pulsing: Boolean) {
    val pulse = rememberInfiniteTransition(label = "pulse")
    val grow by pulse.animateFloat(1f, 2.1f, infiniteRepeatable(tween(1150, easing = LinearEasing), RepeatMode.Restart), label = "grow")
    Row(
        Modifier.clip(CircleShape).background(color.copy(alpha = 0.14f)).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(contentAlignment = Alignment.Center) {
            if (pulsing) {
                Box(
                    Modifier.size(9.dp).scale(grow).clip(CircleShape)
                        .background(color.copy(alpha = (0.8f * (2.1f - grow) / 1.1f).coerceIn(0f, 0.8f))),
                )
            }
            Box(Modifier.size(9.dp).clip(CircleShape).background(color))
        }
        Spacer(Modifier.width(8.dp))
        Text(title, color = color, fontSize = 15.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun Banner(text: String, icon: ImageVector, tint: Color, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    Row(
        modifier.fillMaxWidth().card(tint.copy(alpha = 0.12f), 16)
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }.padding(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.padding(top = 2.dp).size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text(text, color = tint, fontSize = 15.sp)
    }
}

@Composable
fun Pill(text: String, color: Color) {
    Text(
        text, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(CircleShape).background(color.copy(alpha = 0.16f)).padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, color = C.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = modifier)
}

@Composable
fun ScreenTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, color = C.text, fontSize = 32.sp, fontWeight = FontWeight.Bold, modifier = modifier.padding(top = 8.dp, bottom = 4.dp))
}

/** The speed ring: a 270° arc with a green→blue→cyan→red gradient and nine ticks, as on iOS. */
@Composable
fun SpeedGauge(text: String, unit: String, fraction: Double, tint: Color, modifier: Modifier = Modifier, textSize: TextUnit = 76.sp) {
    val sweep by animateFloatAsState(fraction.coerceIn(0.0, 1.0).toFloat(), tween(450), label = "gauge")
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = 18.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawCircle(Color.White.copy(alpha = 0.16f), radius = size.minDimension / 2 - inset, style = Stroke(stroke))
            val radius = size.minDimension / 2
            for (tick in 0 until 9) {
                rotate(tick * 28f - 112f) {
                    val long = tick % 2 == 0
                    val length = (if (long) 12 else 8).dp.toPx()
                    val start = Offset(center.x, center.y - radius + stroke + 4.dp.toPx())
                    drawLine(
                        Color.White.copy(alpha = if (long) 0.85f else 0.35f), start, start.copy(y = start.y + length),
                        strokeWidth = (if (long) 3 else 2).dp.toPx(), cap = StrokeCap.Round,
                    )
                }
            }
            if (sweep > 0.001f) {
                // iOS draws the trim from 0.12 to 0.12+0.76f of a circle rotated by 90°: start at 133° and sweep up to 274°.
                val brush = Brush.sweepGradient(listOf(C.pisteGreen, C.pisteBlue, C.accent, C.pisteRed, C.pisteGreen), center)
                rotate(90f) {
                    drawArc(
                        brush, startAngle = 43.2f, sweepAngle = 273.6f * sweep, useCenter = false,
                        topLeft = Offset(inset, inset), size = arcSize, style = Stroke(stroke, cap = StrokeCap.Round),
                    )
                }
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 36.dp)) {
            AutoText(text, textSize, FontWeight.ExtraBold, tint)
            Text(unit, color = C.snow, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold)
        }
    }
}

/** Speed colour stops, as on the iOS map legend. */
@Composable
fun SpeedLegend(relative: Boolean, onRelative: (Boolean) -> Unit, label: String) {
    Column(Modifier.card(C.background.copy(alpha = 0.82f), 14).padding(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SpeedPaint.stops.forEach { (kmh, hex) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(Color(0xFF000000.toInt() or hex)))
                    Spacer(Modifier.width(4.dp))
                    Text(if (kmh == 0.0) "<15" else "${kmh.toInt()}", color = C.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
            Text(label, color = C.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            androidx.compose.material3.Switch(checked = relative, onCheckedChange = onRelative)
        }
    }
}
