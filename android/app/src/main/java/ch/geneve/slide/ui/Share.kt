package ch.geneve.slide.ui

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import ch.geneve.slide.data.L10n
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.GpxCodec
import ch.geneve.slide.logic.SessionArchive
import ch.geneve.slide.logic.SessionFile
import ch.geneve.slide.logic.UnitPrefs
import java.io.File

/** GPX, stats image and .slide file for one day, shared through the Android share sheet (iOS ShareBar). */
object ShareExport {
    private fun folder(context: Context) = File(context.cacheDir, "share").apply { mkdirs() }

    fun gpx(context: Context, archive: SessionArchive): File =
        File(folder(context), "Slide-${Fmt.fileStamp(archive.startedAt)}.gpx").apply { writeText(GpxCodec.encode(archive)) }

    fun session(context: Context, archive: SessionArchive): File =
        File(folder(context), "Slide-${Fmt.fileStamp(archive.startedAt)}.slide").apply { writeText(SessionFile.encode(archive)) }

    fun image(context: Context, archive: SessionArchive, prefs: UnitPrefs, rider: String): File {
        val file = File(folder(context), "Slide-${Fmt.fileStamp(archive.startedAt)}.png")
        file.outputStream().use { card(archive, prefs, rider).compress(Bitmap.CompressFormat.PNG, 100, it) }
        return file
    }

    fun send(context: Context, file: File, mime: String, title: String) {
        val uri = FileProvider.getUriForFile(context, "ch.geneve.slide.files", file)
        val intent = Intent(Intent.ACTION_SEND).setType(mime).putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(intent, title))
    }

    /** The 360×640 stats card of the iOS StatsCardView, drawn at 3×. */
    fun card(archive: SessionArchive, prefs: UnitPrefs, rider: String): Bitmap {
        val scale = 3f
        val bitmap = Bitmap.createBitmap((360 * scale).toInt(), (640 * scale).toInt(), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(scale, scale)
        val f = L10n.frenchNumbers
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawColor(C.background.toArgb())
        paint.color = C.accent.toArgb()
        canvas.drawRect(0f, 0f, 360f, 6f, paint)

        fun text(value: String, x: Float, y: Float, size: Float, color: Int, bold: Boolean = false, align: Paint.Align = Paint.Align.LEFT, maxWidth: Float = 316f) {
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                textSize = size
                typeface = Typeface.create(Typeface.DEFAULT, if (bold) Typeface.BOLD else Typeface.NORMAL)
                textAlign = align
            }
            while (p.measureText(value) > maxWidth && p.textSize > 8) p.textSize -= 1
            canvas.drawText(value, x, y, p)
        }

        val pad = 22f
        text(L10n.t("tracking.brand"), pad, 36f, 12f, C.accent.toArgb(), bold = true)
        text(Fmt.dayShort(archive.startedAt, L10n.locale), 360 - pad, 36f, 12f, C.accent.toArgb(), align = Paint.Align.RIGHT)
        text(archive.resort.ifEmpty { L10n.t("summary.saved") }, pad, 70f, 20f, C.text.toArgb(), bold = true)
        var y = 70f
        if (rider.isNotEmpty()) {
            y += 22f
            text(rider, pad, y, 15f, C.muted.toArgb())
        }
        y += 84f
        text(Fmt.speed(archive.maxSpeed, prefs, f), pad, y, 78f, C.bandFor(archive.maxSpeed).toArgb(), bold = true)
        y += 26f
        text("${Fmt.speedUnit(prefs)} ${L10n.t("history.max")}", pad, y, 17f, C.muted.toArgb(), bold = true)

        fun stat(label: String, value: String, x: Float, top: Float) {
            paint.color = C.surface.toArgb()
            canvas.drawRoundRect(RectF(x, top, x + 154f, top + 54f), 12f, 12f, paint)
            text(label, x + 10, top + 20, 12f, C.muted.toArgb(), bold = true, maxWidth = 134f)
            text(value, x + 10, top + 44, 20f, C.text.toArgb(), bold = true, maxWidth = 134f)
        }
        y += 18f
        stat(L10n.t("tracking.stat.distance"), Fmt.distance(archive.distance, prefs, f), pad, y)
        stat(L10n.t("tracking.stat.vertical"), Fmt.altitude(archive.vertical, prefs, f), pad + 162f, y)
        y += 62f
        stat(L10n.t("tracking.stat.runs"), "${archive.runs.size}", pad, y)
        stat(L10n.t("tracking.stat.duration"), Fmt.duration(archive.duration), pad + 162f, y)
        y += 70f

        val box = RectF(pad, y, 360 - pad, y + 180f)
        paint.color = C.surface2.toArgb()
        canvas.drawRoundRect(box, 16f, 16f, paint)
        sketch(canvas, archive, RectF(box.left + 8, box.top + 8, box.right - 8, box.bottom - 8))

        val bottom = box.bottom + 30f
        text(L10n.t("card.offline"), pad, bottom, 12f, C.muted.toArgb(), bold = true, maxWidth = 200f)
        if (archive.jumpCount > 0) {
            text(L10n.t("card.air", Fmt.decimal(archive.airtime, 1, french = f)), 360 - pad, bottom, 12f, C.muted.toArgb(), bold = true, align = Paint.Align.RIGHT, maxWidth = 120f)
        }
        return bitmap
    }

    /** The track drawn without a map, coloured by speed band (iOS TrackSketch). */
    private fun sketch(canvas: Canvas, archive: SessionArchive, rect: RectF) {
        val samples = TrackGeometry.simplify(archive.samples, 900)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3.5f
            strokeCap = Paint.Cap.ROUND
        }
        if (samples.size < 2) {
            paint.style = Paint.Style.FILL
            paint.color = C.accent.toArgb()
            canvas.drawCircle(rect.centerX(), rect.centerY(), 5f, paint)
            return
        }
        val minLat = samples.minOf { it.latitude }
        val maxLat = samples.maxOf { it.latitude }
        val minLon = samples.minOf { it.longitude }
        val maxLon = samples.maxOf { it.longitude }
        val inset = 16f
        val xSpan = maxOf(maxLon - minLon, 0.00008)
        val ySpan = maxOf(maxLat - minLat, 0.00008)
        fun x(lon: Double) = (rect.left + inset + (lon - minLon) / xSpan * (rect.width() - inset * 2)).toFloat()
        fun y(lat: Double) = (rect.top + inset + (maxLat - lat) / ySpan * (rect.height() - inset * 2)).toFloat()
        for (i in 1 until samples.size) {
            paint.color = C.bandFor(samples[i].speed).toArgb()
            canvas.drawLine(x(samples[i - 1].longitude), y(samples[i - 1].latitude), x(samples[i].longitude), y(samples[i].latitude), paint)
        }
    }
}

@Composable
fun ShareBar(archive: SessionArchive, prefs: UnitPrefs, rider: String) {
    val context = LocalContext.current
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ShareButton(L10n.t("share.gpx"), Icons.Default.Map, Modifier.weight(1f)) {
            ShareExport.send(context, ShareExport.gpx(context, archive), "application/gpx+xml", L10n.t("share.gpx"))
        }
        ShareButton(L10n.t("share.image"), Icons.Default.Image, Modifier.weight(1f)) {
            ShareExport.send(context, ShareExport.image(context, archive, prefs, rider), "image/png", L10n.t("share.image"))
        }
        ShareButton(L10n.t("share.file"), Icons.Default.Description, Modifier.weight(1f)) {
            ShareExport.send(context, ShareExport.session(context, archive), "application/octet-stream", L10n.t("share.file"))
        }
    }
}

@Composable
private fun ShareButton(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.height(64.dp).card(C.surface2, 16).clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = C.text, modifier = Modifier.size(20.dp))
        Spacer(Modifier.height(6.dp))
        Text(title, color = C.text, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}
