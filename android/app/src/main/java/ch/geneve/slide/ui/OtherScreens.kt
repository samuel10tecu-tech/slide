package ch.geneve.slide.ui

import android.content.Intent
import android.net.Uri
import android.provider.Settings
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ch.geneve.slide.data.CoachSettings
import ch.geneve.slide.data.DayStore
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Profile
import ch.geneve.slide.data.TrickNotes
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.logic.Trick
import ch.geneve.slide.logic.TrickLibrary
import ch.geneve.slide.track.Coach
import ch.geneve.slide.track.Tracking
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.runtime.LaunchedEffect

// region Map

@Composable
fun MapScreen(onOpen: (String) -> Unit) {
    var tracks by remember { mutableStateOf<List<DrawnTrack>>(emptyList()) }
    var group by remember { mutableStateOf<PlaceCluster?>(null) }
    val days = DayStore.days
    val relative = Profile.relativeSpeed
    LaunchedEffect(days.map { it.id to it.startedAt }, relative) {
        tracks = withContext(Dispatchers.IO) {
            days.mapNotNull { day ->
                val archive = DayStore.read(day.id) ?: return@mapNotNull null
                val samples = TrackGeometry.simplify(archive.samples, 400)
                if (samples.size < 2) return@mapNotNull null
                val peak = samples.maxOf { it.speed }
                DrawnTrack(
                    day.id, samples, samples.sumOf { it.latitude } / samples.size, samples.sumOf { it.longitude } / samples.size,
                    if (relative && peak > 1) peak * 3.6 else null,
                )
            }
        }
    }
    Box(Modifier.fillMaxSize()) {
        WorldMap(tracks, Modifier.fillMaxSize(), onOpen) { group = it }
        Column(Modifier.fillMaxSize().padding(12.dp)) {
            Text(L10n.t("map.title"), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.background(C.background.copy(alpha = 0.8f), CircleShape).padding(horizontal = 14.dp, vertical = 8.dp))
            if (days.isEmpty()) {
                Spacer(Modifier.height(10.dp))
                Text(L10n.t("map.empty"), color = C.snow, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.card(C.background.copy(alpha = 0.85f), 16).padding(14.dp))
            }
            Spacer(Modifier.weight(1f))
            SpeedLegend(relative, { Profile.setRelative(it) }, L10n.t("legend.relative"))
            Spacer(Modifier.height(16.dp))
        }
    }
    group?.let { cluster ->
        AlertDialog(
            onDismissRequest = { group = null },
            title = { Text(L10n.t("map.cluster", cluster.dayIds.size)) },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    cluster.dayIds.mapNotNull { id -> days.firstOrNull { it.id == id } }.forEach { day ->
                        Column(Modifier.fillMaxWidth().clickable { group = null; onOpen(day.id) }.padding(vertical = 10.dp)) {
                            Text(day.resort.ifEmpty { L10n.t("history.resort.empty") }, color = C.text, fontWeight = FontWeight.Bold)
                            Text(Fmt.dayTitle(day.startedAt, L10n.locale), color = C.muted, fontSize = 14.sp)
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { group = null }) { Text(L10n.t("summary.ok")) } },
            containerColor = C.surface,
        )
    }
}

// endregion

// region Freestyle

private fun Trick.name() = L10n.t("trick.$id.name")
private fun Trick.summary() = L10n.t("trick.$id.summary")
private fun Trick.levelName() = L10n.t("level.${level.key}")
private fun Trick.categoryName() = L10n.t("cat.$category")

@Composable
fun FreestyleScreen(onOpen: (String) -> Unit) {
    var course by remember { mutableStateOf<Trick.Course?>(null) }
    var query by remember { mutableStateOf("") }
    val learned = TrickNotes.entries.filterValues { it.learned }.keys
    val text = query.trim()
    val filtered = TrickLibrary.tricks.filter { trick ->
        (course == null || trick.level.course == course) &&
            (text.isEmpty() || listOf(trick.name(), trick.summary(), trick.categoryName()).any { it.contains(text, ignoreCase = true) })
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        ScreenTitle(L10n.t("freestyle.learn"))
        Column(Modifier.fillMaxWidth().card(radius = 20).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val total = TrickLibrary.tricks.size
            val done = learned.count { id -> TrickLibrary.trick(id) != null }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("$done / $total", color = C.text, fontSize = 24.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(L10n.t("freestyle.progress"), color = C.muted, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            }
            Box(Modifier.fillMaxWidth().height(8.dp).background(C.surface2, CircleShape)) {
                Box(Modifier.fillMaxWidth(if (total == 0) 0f else done / total.toFloat()).height(8.dp).background(C.accent, CircleShape))
            }
            Text(L10n.t("freestyle.offline"), color = C.muted, fontSize = 13.sp)
        }
        Box(Modifier.fillMaxWidth().card(radius = 16).padding(14.dp)) {
            if (query.isEmpty()) Text(L10n.t("freestyle.search"), color = C.muted, fontSize = 17.sp)
            BasicTextField(query, { query = it }, singleLine = true, cursorBrush = SolidColor(C.accent),
                textStyle = TextStyle(color = C.text, fontSize = 17.sp), modifier = Modifier.fillMaxWidth())
        }
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip(L10n.t("freestyle.filter.all"), course == null) { course = null }
            Trick.Course.entries.forEach { item ->
                Chip(L10n.t("freestyle.course.${item.key}"), course == item) { course = if (course == item) null else item }
            }
        }
        if (query.isEmpty() && course == null) {
            Banner(L10n.t("freestyle.pinned"), Icons.Default.Shield, C.accent) { onOpen("park-rules") }
        }
        if (filtered.isEmpty()) Text(L10n.t("freestyle.empty"), color = C.muted, modifier = Modifier.padding(top = 12.dp))
        Trick.Course.entries.forEach { item ->
            val rows = filtered.filter { it.level.course == item }
            if (rows.isNotEmpty()) {
                val tint = when (item) { Trick.Course.BEGINNER -> C.pisteGreen; Trick.Course.PARK -> C.pisteBlue; else -> C.pisteRed }
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 6.dp)) {
                    Box(Modifier.width(4.dp).height(18.dp).background(tint, RoundedCornerShape(2.dp)))
                    Spacer(Modifier.width(8.dp))
                    Text(L10n.t("freestyle.course.${item.key}"), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.Black)
                }
                rows.forEach { trick -> TrickRow(trick, trick.id in learned) { onOpen(trick.id) } }
            }
        }
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun Chip(title: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        title, color = if (selected) C.ink else C.text, fontSize = 15.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.background(if (selected) C.accent else C.surface, CircleShape).clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

@Composable
private fun TrickRow(trick: Trick, learned: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().card().clickable(onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(if (learned) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked, null, tint = if (learned) C.accent else C.muted)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(trick.name(), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Row {
                Text(trick.levelName(), color = C.level(trick.level), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Text(" · ${trick.categoryName()}", color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                if (trick.requiresCoach) Text(" · ${L10n.t("freestyle.coach")}", color = C.pink, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = C.muted)
    }
}

@Composable
fun TrickDetailScreen(id: String, onBack: () -> Unit) {
    val trick = TrickLibrary.trick(id) ?: return
    val context = LocalContext.current
    val entry = TrickNotes.entry(id)
    var note by remember { mutableStateOf(entry.note) }
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 4.dp)) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = C.accent) }
            Text(trick.name(), color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Pill(trick.levelName(), C.level(trick.level))
                Text(trick.categoryName(), color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                if (trick.requiresCoach) Pill(L10n.t("freestyle.coach"), C.pink)
            }
            Text(trick.summary(), color = C.text, fontSize = 17.sp)
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle(L10n.t("freestyle.how"))
                (0 until trick.stepCount).forEach { index ->
                    Row(verticalAlignment = Alignment.Top) {
                        Box(Modifier.size(22.dp).background(C.accent, CircleShape), contentAlignment = Alignment.Center) {
                            Text("${index + 1}", color = Color.Black, fontSize = 12.sp, fontWeight = FontWeight.Black)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(L10n.t("trick.$id.step.$index"), color = C.text, fontSize = 15.sp)
                    }
                }
            }
            Row(
                Modifier.fillMaxWidth().card(C.accent, 14).clickable {
                    val url = "https://www.youtube.com/results?search_query=" + Uri.encode("ski ${trick.name()} tutorial")
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }.padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.PlayCircle, null, tint = C.ink)
                Spacer(Modifier.width(8.dp))
                Text(L10n.t("freestyle.watch"), color = C.ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
            Banner(L10n.t("trick.$id.safety"), Icons.Default.Shield, C.orange)
            if (trick.tipCount > 0) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SectionTitle(L10n.t("freestyle.mistakes"))
                    (0 until trick.tipCount).forEach { index ->
                        Row {
                            Icon(Icons.Default.AutoAwesome, null, tint = C.accent, modifier = Modifier.size(16.dp).padding(top = 2.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(L10n.t("trick.$id.tip.$index"), color = C.text, fontSize = 15.sp)
                        }
                    }
                }
            }
            val on = entry.learned
            Row(
                Modifier.fillMaxWidth().card(radius = 16).clickable {
                    TrickNotes.update(id) { it.copy(learned = !it.learned, learnedAt = if (!it.learned) System.currentTimeMillis() / 1000.0 else null) }
                }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(if (on) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked, null, tint = if (on) C.accent else C.text, modifier = Modifier.size(28.dp))
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(L10n.t(if (on) "freestyle.learned" else "freestyle.notyet"), color = if (on) C.accent else C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    val at = entry.learnedAt
                    Text(if (on && at != null) Fmt.dayTitle(at, L10n.locale) else L10n.t("freestyle.learned.hint"), color = C.muted, fontSize = 12.sp)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionTitle(L10n.t("freestyle.notes"))
                Box(Modifier.fillMaxWidth().heightIn(min = 120.dp).card(C.surface2, 14).padding(12.dp)) {
                    BasicTextField(note, { value ->
                        note = value
                        TrickNotes.update(id) { it.copy(note = value) }
                    }, cursorBrush = SolidColor(C.accent), textStyle = TextStyle(color = C.text, fontSize = 15.sp), modifier = Modifier.fillMaxWidth())
                }
            }
            Spacer(Modifier.height(20.dp))
        }
    }
}

// endregion

// region Voice

@Composable
fun VoiceScreen() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        ScreenTitle(L10n.t("voice.title"))
        Text(L10n.t("voice.lead"), color = C.muted, fontSize = 15.sp)
        CoachCard()
        Text(L10n.t("android.voice.shortcuts"), color = C.text, fontSize = 20.sp, fontWeight = FontWeight.Black)
        Text(L10n.t("android.voice.shortcuts.help"), color = C.muted, fontSize = 13.sp)
        listOf("siri.title.max", "siri.title.distance").forEach { key ->
            Text("“${L10n.t(key)}”", color = C.snow, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth().card(radius = 16).padding(14.dp))
        }
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun CoachCard() {
    val context = LocalContext.current
    Column(Modifier.fillMaxWidth().card().padding(14.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ToggleRow(L10n.t("audio.title"), L10n.t("audio.detail"), CoachSettings.enabled) { CoachSettings.setEnabled(it) }
        if (CoachSettings.enabled) {
            SliderRow(L10n.t("audio.threshold"), "${CoachSettings.thresholdKmh.toInt()} km/h", CoachSettings.thresholdKmh.toFloat(), 20f..130f, 21) {
                CoachSettings.setThreshold((Math.round(it / 5f) * 5f).toDouble())
            }
            SliderRow(L10n.t("audio.every"), "%.1f km".format(CoachSettings.everyKm), CoachSettings.everyKm.toFloat(), 0.5f..10f, 18) {
                CoachSettings.setEvery((Math.round(it * 2f) / 2f).toDouble())
            }
            val period = CoachSettings.periodMinutes
            SliderRow(L10n.t("audio.period"), if (period < 1) L10n.t("audio.period.off") else "$period min", period.toFloat(), 0f..30f, 29) {
                CoachSettings.setPeriod(Math.round(it))
            }
            Text(L10n.t("audio.include"), color = C.muted, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            CoachSettings.partKeys.forEach { key ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(L10n.t("audio.part.$key"), color = C.text, fontSize = 15.sp, modifier = Modifier.weight(1f))
                    Switch(CoachSettings.part(key), { CoachSettings.setPart(key, it) }, colors = SwitchDefaults.colors(checkedTrackColor = C.accent))
                }
            }
            Row(
                Modifier.fillMaxWidth().card(C.accent, 14).clickable { Coach.test(context) }.padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.VolumeUp, null, tint = C.ink)
                Spacer(Modifier.width(8.dp))
                Text(L10n.t("audio.test"), color = C.ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun ToggleRow(title: String, detail: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(detail, color = C.muted, fontSize = 13.sp)
        }
        Switch(checked, onChange, colors = SwitchDefaults.colors(checkedTrackColor = C.accent))
    }
}

@Composable
private fun SliderRow(title: String, value: String, current: Float, range: ClosedFloatingPointRange<Float>, steps: Int, onChange: (Float) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row {
            Text(title, color = C.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Text(value, color = C.accent, fontSize = 15.sp, fontWeight = FontWeight.Black)
        }
        Slider(current, onChange, valueRange = range, steps = steps, colors = SliderDefaults.colors(thumbColor = C.accent, activeTrackColor = C.accent))
    }
}

// endregion

// region Profile

@Composable
fun ProfileScreen(locationGranted: Boolean, locationAsked: Boolean) {
    val context = LocalContext.current
    var confirmErase by remember { mutableStateOf(false) }
    var languageMenu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        ScreenTitle(L10n.t("profile.title"))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(L10n.t("profile.language"), color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Box {
                val current = L10n.choices.first { it.first == L10n.choice }
                Text(
                    if (current.first == "system") L10n.t("profile.language.system") else current.second,
                    color = C.accent, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.card(radius = 14).clickable { languageMenu = true }.padding(horizontal = 14.dp, vertical = 10.dp),
                )
                DropdownMenu(languageMenu, { languageMenu = false }) {
                    L10n.choices.forEach { (code, endonym) ->
                        DropdownMenuItem(
                            text = { Text(if (code == "system") L10n.t("profile.language.system") else endonym) },
                            onClick = { L10n.choose(code); languageMenu = false },
                        )
                    }
                }
            }
            Text(L10n.t("android.profile.language.note"), color = C.muted, fontSize = 13.sp)
        }
        Field(L10n.t("profile.name"), Profile.name, L10n.t("profile.name.prompt")) { Profile.setName(it) }
        Field(L10n.t("profile.resort"), Profile.homeMountain, L10n.t("profile.resort.prompt")) { Profile.setHome(it) }
        Text(L10n.t("profile.hint"), color = C.muted, fontSize = 13.sp)
        val u = Profile.units
        UnitPicker(L10n.t("profile.speed"), L10n.t("profile.unit.kmh"), L10n.t("profile.unit.mph"), u.speedMetric) { Profile.setUnits(u.copy(speedMetric = it)) }
        UnitPicker(L10n.t("profile.distance"), L10n.t("profile.unit.km"), L10n.t("profile.unit.mi"), u.distanceMetric) { Profile.setUnits(u.copy(distanceMetric = it)) }
        UnitPicker(L10n.t("profile.altitude"), L10n.t("profile.unit.m"), L10n.t("profile.unit.ft"), u.altitudeMetric) { Profile.setUnits(u.copy(altitudeMetric = it)) }
        Box(Modifier.card(radius = 16).padding(14.dp)) {
            ToggleRow(L10n.t("profile.screen"), L10n.t("profile.screen.detail"), Profile.keepScreenOn) { Profile.setKeepScreenOn(it) }
        }
        Column(Modifier.fillMaxWidth().card(radius = 16).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionTitle(L10n.t("profile.location"))
            Text(
                when {
                    locationGranted -> L10n.t("android.profile.location.granted")
                    locationAsked -> L10n.t("profile.location.denied")
                    else -> L10n.t("android.profile.location.unknown")
                },
                color = C.muted, fontSize = 15.sp,
            )
            Text(L10n.t("android.profile.location.open"), color = C.accent, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable {
                    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                })
        }
        RowButton(L10n.t("profile.sample"), L10n.t("profile.sample.detail"), Icons.Default.AutoAwesome) { Tracking.toggleSampleDay() }
        RowButton(L10n.t("profile.erase"), L10n.t("profile.erase.detail"), Icons.Default.Delete) { confirmErase = true }
        Column(Modifier.fillMaxWidth().card().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle(L10n.t("profile.about.title"))
            listOf("profile.about.1", "profile.about.2", "profile.about.3", "android.profile.about.4", "android.profile.about.5").forEach {
                Text(L10n.t(it), color = C.muted, fontSize = 15.sp)
            }
        }
        Spacer(Modifier.height(20.dp))
    }
    if (confirmErase) {
        AlertDialog(
            onDismissRequest = { confirmErase = false },
            title = { Text(L10n.t("profile.erase.title")) },
            text = { Text(L10n.t("profile.erase.message")) },
            confirmButton = {
                TextButton(onClick = { confirmErase = false; Tracking.eraseAll() }) { Text(L10n.t("profile.erase.confirm"), color = C.danger) }
            },
            dismissButton = { TextButton(onClick = { confirmErase = false }) { Text(L10n.t("history.cancel")) } },
            containerColor = C.surface,
        )
    }
}

@Composable
private fun Field(title: String, value: String, prompt: String, onChange: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Box(Modifier.fillMaxWidth().card(radius = 16).padding(14.dp)) {
            if (value.isEmpty()) Text(prompt, color = C.muted, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
            BasicTextField(value, onChange, singleLine = true, cursorBrush = SolidColor(C.accent),
                textStyle = TextStyle(color = C.text, fontSize = 20.sp, fontWeight = FontWeight.SemiBold), modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun UnitPicker(title: String, metric: String, imperial: String, isMetric: Boolean, onChange: (Boolean) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, color = C.muted, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf(true to metric, false to imperial).forEachIndexed { index, (value, label) ->
                SegmentedButton(
                    selected = isMetric == value, onClick = { onChange(value) },
                    shape = SegmentedButtonDefaults.itemShape(index, 2),
                    colors = SegmentedButtonDefaults.colors(activeContainerColor = C.surface2, activeContentColor = C.accent, inactiveContainerColor = C.surface),
                ) { Text(label) }
            }
        }
    }
}

@Composable
private fun RowButton(title: String, detail: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().card(radius = 16).clickable(onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = C.accent, modifier = Modifier.width(28.dp))
        Spacer(Modifier.width(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = C.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(detail, color = C.muted, fontSize = 13.sp)
        }
    }
}

// endregion
