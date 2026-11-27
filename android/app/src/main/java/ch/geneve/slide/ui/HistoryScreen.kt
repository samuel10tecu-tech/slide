package ch.geneve.slide.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.DownhillSkiing
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ch.geneve.slide.data.DayMeta
import ch.geneve.slide.data.DayStore
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Profile
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.SessionArchive
import ch.geneve.slide.logic.Season
import ch.geneve.slide.logic.Units
import ch.geneve.slide.track.Tracking
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

data class SeasonRollup(
    val season: Season,
    val days: Int,
    val runs: Int,
    val distance: Double,
    val vertical: Double,
    val topSpeed: Double,
    val topSpeedDate: Double?,
    val longestRun: Double,
    val longestRunDate: Double?,
    val bestDayVertical: Double,
    val bestDayDate: Double?,
) {
    companion object {
        fun make(days: List<DayMeta>, season: Season): SeasonRollup {
            val inside = days.filter { it.startedAt in season }
            val top = inside.maxByOrNull { it.maxSpeed }?.takeIf { it.maxSpeed > 0 }
            val long = inside.maxByOrNull { it.longestRun }?.takeIf { it.longestRun > 0 }
            val best = inside.maxByOrNull { it.vertical }?.takeIf { it.vertical > 0 }
            return SeasonRollup(
                season, inside.size, inside.sumOf { it.runCount }, inside.sumOf { it.distance }, inside.sumOf { it.vertical },
                top?.maxSpeed ?: 0.0, top?.startedAt, long?.longestRun ?: 0.0, long?.startedAt, best?.vertical ?: 0.0, best?.startedAt,
            )
        }
    }
}

@Composable
fun HistoryScreen(onOpen: (String) -> Unit) {
    val context = LocalContext.current
    val days = DayStore.days
    val prefs = Profile.units
    val current = Season.containing(System.currentTimeMillis() / 1000.0)
    val rollup = SeasonRollup.make(days, current)
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) Tracking.importUri(context, uri)
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ScreenTitle(L10n.t("history.title"), Modifier.weight(1f))
            IconButton(onClick = { importer.launch(arrayOf("*/*")) }) {
                Icon(Icons.Default.FileDownload, L10n.t("history.import"), tint = C.accent)
            }
        }
        SeasonHeader(rollup)
        RecordsRow(rollup)
        DaySection(L10n.t("history.section.now"), days.filter { it.startedAt in current }, onOpen)
        days.filterNot { it.startedAt in current }
            .groupBy { Season.containing(it.startedAt) }
            .toSortedMap(compareByDescending { it.start })
            .forEach { (season, list) -> DaySection(season.title, list, onOpen) }
        if (days.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(vertical = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.Landscape, null, tint = C.accent, modifier = Modifier.size(42.dp))
                Spacer(Modifier.height(12.dp))
                Text(L10n.t("history.empty.title"), color = C.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(6.dp))
                Text(L10n.t("history.empty.body"), color = C.muted, fontSize = 15.sp, textAlign = TextAlign.Center)
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun SeasonHeader(rollup: SeasonRollup) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    Column(Modifier.fillMaxWidth().card(C.surface.copy(alpha = 0.75f), 22).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(rollup.season.title, color = C.accent, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        Row {
            Big(Fmt.altitude(rollup.vertical, prefs, f), L10n.t("tracking.stat.vertical"), Modifier.weight(1.4f))
            Big("${rollup.days}", L10n.t(if (rollup.days > 1) "history.season.days" else "history.season.day"), Modifier.weight(1f))
            Big("${rollup.runs}", L10n.t(if (rollup.runs > 1) "history.season.runs" else "history.season.run"), Modifier.weight(1f))
        }
        Text("${Fmt.distance(rollup.distance, prefs, f)} ${L10n.t("history.season.distance")}", color = C.muted, fontSize = 15.sp)
    }
}

@Composable
private fun Big(value: String, label: String, modifier: Modifier) {
    Column(modifier) {
        AutoText(value, 28.sp, FontWeight.Bold, C.text)
        Text(label, color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun RecordsRow(rollup: SeasonRollup) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    fun date(t: Double?, none: String) = t?.let { Fmt.dayShort(it, L10n.locale) } ?: L10n.t(none)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Record(L10n.t("history.record.speed"), if (rollup.topSpeed > 0) Fmt.speed(rollup.topSpeed, prefs, f) else "—", date(rollup.topSpeedDate, "history.record.none.speed"), C.accent)
        Record(L10n.t("history.record.longest"), if (rollup.longestRun > 0) Fmt.distance(rollup.longestRun, prefs, f) else "—", date(rollup.longestRunDate, "history.record.none.long"), C.ice)
        Record(L10n.t("history.record.day"), if (rollup.bestDayVertical > 0) Fmt.altitude(rollup.bestDayVertical, prefs, f) else "—", date(rollup.bestDayDate, "history.record.none.vert"), C.orange)
    }
}

@Composable
private fun Record(title: String, value: String, detail: String, tint: androidx.compose.ui.graphics.Color) {
    Column(Modifier.width(168.dp).card(C.surface.copy(alpha = 0.75f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, color = tint, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        AutoText(value, 22.sp, FontWeight.Bold, C.text)
        Text(detail, color = C.muted, fontSize = 12.sp, maxLines = 1)
    }
}

@Composable
private fun DaySection(title: String, days: List<DayMeta>, onOpen: (String) -> Unit) {
    if (days.isEmpty()) return
    Text(title, color = C.muted, fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
    days.forEach { DayRow(it) { onOpen(it.id) } }
}

@Composable
private fun DayRow(day: DayMeta, onClick: () -> Unit) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    Column(Modifier.fillMaxWidth().card(radius = 20).clickable(onClick = onClick).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(Fmt.dayTitle(day.startedAt, L10n.locale), color = C.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            if (day.isSample) Pill(L10n.t("history.example"), C.ice)
            if (!day.isComplete) {
                Spacer(Modifier.width(6.dp))
                Pill(L10n.t("history.open"), C.orange)
            }
        }
        Text(day.resort.ifEmpty { L10n.t("history.resort.empty") }, color = C.muted, fontSize = 12.sp)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(Fmt.speed(day.maxSpeed, prefs, f), color = C.bandFor(day.maxSpeed), fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Text(Fmt.speedUnit(prefs), color = C.muted, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(bottom = 6.dp))
        }
        Text(
            "${Fmt.distance(day.distance, prefs, f)} · ${Fmt.altitude(day.vertical, prefs, f)} · ${day.runCount} · ${Fmt.duration(day.duration)}",
            color = C.muted, fontSize = 13.sp,
        )
    }
}

/** One day: stats, map with replay, charts, runs, jumps and sharing (iOS DayDetailView). */
@Composable
fun DayDetailScreen(id: String, onBack: () -> Unit) {
    val meta = DayStore.days.firstOrNull { it.id == id }
    var archive by remember { mutableStateOf<SessionArchive?>(null) }
    var missing by remember { mutableStateOf(false) }
    var resort by remember { mutableStateOf(meta?.resort ?: "") }
    var picked by remember { mutableStateOf<ch.geneve.slide.logic.TrackSample?>(null) }
    var playing by remember { mutableStateOf(false) }
    var replayIndex by remember { mutableIntStateOf(0) }
    var confirmDelete by remember { mutableStateOf(false) }
    val prefs = Profile.units
    val f = L10n.frenchNumbers

    LaunchedEffect(id) {
        archive = withContext(Dispatchers.IO) { DayStore.read(id) }
        missing = archive == null
    }
    LaunchedEffect(playing) {
        while (playing) {
            val count = archive?.samples?.size ?: 0
            if (count > 1) replayIndex = (replayIndex + maxOf(1, count / 700)) % count
            delay(50)
        }
    }
    DisposableEffect(id) {
        onDispose {
            val trimmed = resort.trim()
            if (meta != null && trimmed != meta.resort) Thread { DayStore.rename(id, trimmed) }.start()
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 4.dp)) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = C.accent) }
            Text(meta?.let { Fmt.dayShort(it.startedAt, L10n.locale) } ?: "", color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (meta?.isSample == true) Banner(L10n.t("history.sample.banner"), Icons.Default.AutoAwesome, C.ice)
            Box(Modifier.fillMaxWidth().card(radius = 16).padding(14.dp)) {
                if (resort.isEmpty()) Text(L10n.t("history.resort.placeholder"), color = C.muted, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                BasicTextField(
                    resort, { resort = it }, singleLine = true, cursorBrush = SolidColor(C.accent),
                    textStyle = TextStyle(color = C.text, fontSize = 20.sp, fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            val a = archive
            if (a != null) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(Fmt.speed(a.maxSpeed, prefs, f), color = C.snow, fontSize = 64.sp, fontWeight = FontWeight.ExtraBold)
                    Text(Fmt.speedUnit(prefs), color = C.accent, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold)
                }
                Grid(
                    listOf(
                        Triple(L10n.t("tracking.stat.max"), Fmt.speed(a.maxSpeed, prefs, f), Icons.Default.Flag),
                        Triple(L10n.t("tracking.stat.distance"), Fmt.distance(a.distance, prefs, f), Icons.Default.Straighten),
                        Triple(L10n.t("tracking.stat.vertical"), Fmt.altitude(a.vertical, prefs, f), Icons.Default.ArrowDownward),
                        Triple(L10n.t("tracking.stat.duration"), Fmt.duration(a.duration), Icons.Default.Timer),
                        Triple(L10n.t("tracking.stat.runs"), "${a.runs.size}", Icons.Default.Landscape),
                        Triple(L10n.t("history.jumps"), "${a.jumpCount}", Icons.Default.ArrowUpward),
                    ),
                ) { (label, value, icon), modifier -> StatTile(label, value, icon, modifier) }

                val dayMax = if (Profile.relativeSpeed && a.maxSpeed > 1) a.maxSpeed * 3.6 else null
                if (a.samples.size >= 2) {
                    TrackMap(
                        a.samples, follow = false,
                        replay = if (playing || replayIndex > 0) a.samples[minOf(replayIndex, a.samples.size - 1)] else null,
                        dayMaxKmh = dayMax,
                        modifier = Modifier.fillMaxWidth().height(300.dp).card(radius = 20),
                    ) { picked = it }
                    SpeedLegend(Profile.relativeSpeed, { Profile.setRelative(it) }, L10n.t("legend.relative"))
                    picked?.let {
                        Text(
                            "${L10n.t("history.point.speed")} · ${Fmt.speed(it.speed, prefs, f)} ${Fmt.speedUnit(prefs)} · ${Fmt.altitude(it.rawAltitude, prefs, f)} · ${Fmt.clock(it.time)}",
                            color = C.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                        )
                    }
                    Text(L10n.t("history.map.note"), color = C.muted, fontSize = 13.sp)
                } else {
                    Banner(L10n.t("history.map.empty"), Icons.Default.Map, C.muted)
                }
                if (a.samples.size > 2) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            SectionTitle(L10n.t("history.replay"), Modifier.weight(1f))
                            TextButton(onClick = { playing = !playing }) {
                                Text(L10n.t(if (playing) "history.replay.pause" else "history.replay.play"), color = C.accent, fontWeight = FontWeight.Bold)
                            }
                        }
                        Slider(
                            value = replayIndex.toFloat(), onValueChange = { replayIndex = it.toInt() },
                            valueRange = 0f..(a.samples.size - 1).coerceAtLeast(1).toFloat(),
                            colors = SliderDefaults.colors(thumbColor = C.accent, activeTrackColor = C.accent),
                        )
                        val s = a.samples[minOf(replayIndex, a.samples.size - 1)]
                        Text("${Fmt.speed(s.speed, prefs, f)} ${Fmt.speedUnit(prefs)} · ${Fmt.altitude(s.rawAltitude, prefs, f)}", color = C.muted, fontSize = 15.sp)
                    }
                    Box(Modifier.card().padding(14.dp)) {
                        SpeedAltitudeChart(a.samples, prefs, L10n.t("history.chart.speed"), L10n.t("history.chart.altitude"))
                    }
                }
                Box(Modifier.card().padding(14.dp)) { RunBarChart(a.runs, prefs, L10n.t("history.chart.runs")) }
                RunsBlock(a)
                if (a.jumps.isNotEmpty()) {
                    Column(Modifier.fillMaxWidth().card(radius = 16).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        SectionTitle(L10n.t("history.jumps"))
                        Text(L10n.t("history.jumps.line", a.jumpCount, Fmt.decimal(a.airtime, 1, french = f)), color = C.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                        Text(L10n.t("history.jumps.note"), color = C.muted, fontSize = 13.sp)
                    }
                }
                ShareBar(a.copy(resort = resort.trim()), prefs, Profile.name.trim().ifEmpty { a.riderName })
                Text(L10n.t("history.share.hint"), color = C.muted, fontSize = 13.sp)
            } else if (missing) {
                Banner(L10n.t("history.broken"), Icons.Default.Warning, C.danger)
            }
            TextButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
                Text(L10n.t("history.delete"), color = C.danger)
            }
            Spacer(Modifier.height(20.dp))
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(L10n.t("history.delete.title")) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    DayStore.delete(id)
                    Tracking.refreshRecovery()
                    onBack()
                }) { Text(L10n.t("history.delete.confirm"), color = C.danger) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(L10n.t("history.cancel")) } },
            containerColor = C.surface,
        )
    }
}

@Composable
private fun RunsBlock(a: SessionArchive) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionTitle(L10n.t("history.runs"))
        if (a.runs.isEmpty()) Text(L10n.t("history.runs.empty"), color = C.muted, fontSize = 15.sp)
        a.runs.forEach { run ->
            Row(Modifier.fillMaxWidth().card(radius = 16), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.padding(start = 6.dp).width(6.dp).height(64.dp).background(C.bandFor(run.maxSpeed), RoundedCornerShape(3.dp)))
                Column(Modifier.weight(1f).padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(L10n.t("history.run", run.index), color = C.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text("${Fmt.distance(run.distance, prefs, f)} · ${Fmt.altitude(run.verticalDrop, prefs, f)} · ${Fmt.duration(run.duration)}", color = C.muted, fontSize = 13.sp)
                    Text(L10n.t("history.avg", Fmt.speed(run.avgSpeed, prefs, f), Fmt.speedUnit(prefs)), color = C.muted, fontSize = 12.sp)
                }
                Column(horizontalAlignment = Alignment.End, modifier = Modifier.padding(end = 14.dp)) {
                    Text(Fmt.speed(run.maxSpeed, prefs, f), color = C.bandFor(run.maxSpeed), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text(L10n.t("history.max"), color = C.muted, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

/** Shown after Stop (iOS SessionSummarySheet). */
@Composable
fun SummaryScreen(archive: SessionArchive, onDone: () -> Unit) {
    val prefs = Profile.units
    val f = L10n.frenchNumbers
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            Text(L10n.t("summary.title"), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            TextButton(onClick = onDone) { Text(L10n.t("summary.ok"), color = C.accent, fontWeight = FontWeight.Bold) }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(archive.resort.ifEmpty { L10n.t("summary.saved") }, color = C.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                SpeedGauge(
                    Fmt.speed(archive.maxSpeed, prefs, f), Fmt.speedUnit(prefs), Units.kmh(archive.maxSpeed) / 100,
                    C.bandFor(archive.maxSpeed), Modifier.size(220.dp), textSize = 56.sp,
                )
            }
            Grid(
                listOf(
                    Triple(L10n.t("tracking.stat.distance"), Fmt.distance(archive.distance, prefs, f), Icons.Default.Straighten),
                    Triple(L10n.t("tracking.stat.vertical"), Fmt.altitude(archive.vertical, prefs, f), Icons.Default.ArrowDownward),
                    Triple(L10n.t("tracking.stat.runs"), "${archive.runs.size}", Icons.Default.DownhillSkiing),
                    Triple(L10n.t("tracking.stat.duration"), Fmt.duration(archive.duration), Icons.Default.Timer),
                ),
            ) { (label, value, icon), modifier -> StatTile(label, value, icon, modifier) }
            if (archive.samples.size > 2) SpeedAltitudeChart(archive.samples, prefs, L10n.t("history.chart.speed"), L10n.t("history.chart.altitude"))
            RunBarChart(archive.runs, prefs, L10n.t("history.chart.runs"))
            Text(L10n.t("android.summary.share"), color = C.muted, fontSize = 15.sp)
            ShareBar(archive, prefs, Profile.name.trim())
            Spacer(Modifier.height(20.dp))
        }
    }
}
