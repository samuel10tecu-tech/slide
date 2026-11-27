package ch.geneve.slide

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.DownhillSkiing
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import ch.geneve.slide.data.CoachSettings
import ch.geneve.slide.data.DayStore
import ch.geneve.slide.data.L10n
import ch.geneve.slide.data.Profile
import ch.geneve.slide.data.TrickNotes
import ch.geneve.slide.logic.Fmt
import ch.geneve.slide.track.Activity
import ch.geneve.slide.track.Coach
import ch.geneve.slide.track.Notice
import ch.geneve.slide.track.Tracking
import ch.geneve.slide.ui.C
import ch.geneve.slide.ui.DayDetailScreen
import ch.geneve.slide.ui.FreestyleScreen
import ch.geneve.slide.ui.HistoryScreen
import ch.geneve.slide.ui.MapScreen
import ch.geneve.slide.ui.ProfileScreen
import ch.geneve.slide.ui.ScreenBackground
import ch.geneve.slide.ui.SlideTheme
import ch.geneve.slide.ui.SummaryScreen
import ch.geneve.slide.ui.TrackingScreen
import ch.geneve.slide.ui.TrickDetailScreen
import ch.geneve.slide.ui.VoiceScreen
import org.osmdroid.config.Configuration

class MainActivity : ComponentActivity() {
    private var locationGranted by mutableStateOf(false)
    private var locationAsked by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Configuration.getInstance().load(this, getSharedPreferences("osmdroid", MODE_PRIVATE))
        Configuration.getInstance().userAgentValue = packageName
        SlideApp.init(this)
        Preview.start(intent)
        handle(intent)
        setContent { SlideTheme { Root() } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    override fun onResume() {
        super.onResume()
        locationGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        locationAsked = locationAsked || shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION)
        Tracking.refreshRecovery()
    }

    /** Launcher shortcuts speak today's numbers; files opened from other apps are imported. */
    private fun handle(intent: Intent?) {
        val prefs = Profile.units
        when (intent?.action) {
            ACTION_SPEAK_MAX -> Coach.say(
                this, L10n.t("siri.max", "${Fmt.speed(Tracking.todayTotals().maxSpeed, prefs, L10n.frenchNumbers)} ${Fmt.speedUnit(prefs)}"),
            )
            ACTION_SPEAK_DISTANCE -> Coach.say(
                this, L10n.t("siri.distance", Fmt.distance(Tracking.todayTotals().distance, prefs, L10n.frenchNumbers)),
            )
            Intent.ACTION_VIEW, Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = intent.data ?: intent.getParcelableExtra(Intent.EXTRA_STREAM)
                if (uri != null) {
                    Tracking.importUri(this, uri)
                    openHistory = true
                }
            }
        }
    }

    private var openHistory by mutableStateOf(false)

    @Composable
    private fun Root() {
        var tab by rememberSaveable { mutableIntStateOf(Preview.tab) }
        var day by rememberSaveable { mutableStateOf(Preview.day) }
        var trick by rememberSaveable { mutableStateOf(Preview.trick) }
        var summary by rememberSaveable { mutableStateOf(false) }

        LaunchedEffect(Tracking.activity, Profile.keepScreenOn) {
            if (Tracking.activity == Activity.TRACKING && Profile.keepScreenOn) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        LaunchedEffect(openHistory) {
            if (openHistory) {
                tab = 2
                day = null
                openHistory = false
            }
        }
        // Reading L10n.choice makes every screen redraw in the new language.
        @Suppress("UNUSED_VARIABLE") val language = L10n.choice

        BackHandler(enabled = summary || day != null || trick != null) {
            when {
                summary -> summary = false
                trick != null -> trick = null
                else -> day = null
            }
        }

        Scaffold(
            containerColor = C.background,
            bottomBar = {
                if (!summary) {
                    NavigationBar(containerColor = C.surface) {
                        val items = listOf(
                            "tab.tracking" to Icons.Default.Speed, "tab.map" to Icons.Default.Map,
                            "tab.history" to Icons.Default.History, "tab.freestyle" to Icons.Default.DownhillSkiing,
                            "tab.voice" to Icons.Default.GraphicEq, "tab.profile" to Icons.Default.AccountCircle,
                        )
                        items.forEachIndexed { index, (key, icon) ->
                            NavigationBarItem(
                                selected = tab == index,
                                onClick = { tab = index; day = null; trick = null },
                                icon = { Icon(icon, null) },
                                label = { Text(L10n.t(key), maxLines = 1, softWrap = false, fontSize = 11.sp, overflow = TextOverflow.Ellipsis) },
                                alwaysShowLabel = false,
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = C.accent, selectedTextColor = C.accent, indicatorColor = C.surface2,
                                    unselectedIconColor = C.muted, unselectedTextColor = C.muted,
                                ),
                            )
                        }
                    }
                }
            },
        ) { padding ->
            ScreenBackground(Modifier.padding(padding)) {
                Box(Modifier.fillMaxSize()) {
                    val finished = Tracking.lastArchive
                    when {
                        summary && finished != null -> SummaryScreen(finished) { summary = false }
                        day != null -> DayDetailScreen(day!!) { day = null }
                        trick != null -> TrickDetailScreen(trick!!) { trick = null }
                        tab == 0 -> TrackingScreen { summary = true }
                        tab == 1 -> MapScreen { day = it }
                        tab == 2 -> HistoryScreen { day = it }
                        tab == 3 -> FreestyleScreen { trick = it }
                        tab == 4 -> VoiceScreen()
                        else -> ProfileScreen(locationGranted, locationAsked)
                    }
                }
            }
        }

        Tracking.notice?.let { notice ->
            val title = if (notice is Notice.SampleAdded || notice is Notice.SampleRemoved) L10n.t("profile.title") else L10n.t("history.file.title")
            AlertDialog(
                onDismissRequest = { Tracking.notice = null },
                title = { Text(title) },
                text = { Text(notice.message()) },
                confirmButton = { TextButton(onClick = { Tracking.notice = null }) { Text(L10n.t("history.file.ok")) } },
                containerColor = C.surface,
            )
        }
    }

    companion object {
        const val ACTION_SPEAK_MAX = "ch.geneve.slide.SPEAK_MAX"
        const val ACTION_SPEAK_DISTANCE = "ch.geneve.slide.SPEAK_DISTANCE"
    }
}

/** One-time setup shared by the activity and the tracking service. */
object SlideApp {
    private var ready = false

    fun init(context: android.content.Context) {
        if (ready) return
        ready = true
        L10n.init(context)
        Profile.init(context)
        CoachSettings.init(context)
        TrickNotes.init(context)
        DayStore.init(context)
        Tracking.init(context)
    }
}

/**
 * Demo mode for screenshots, like the iOS -slidePreview argument:
 * `adb shell am start -n ch.geneve.slide/.MainActivity --es slidePreview history --es slideLanguage fr`.
 */
object Preview {
    var screen: String? = null
        private set
    var tab = 0
        private set
    var day: String? = null
        private set
    var trick: String? = null
        private set
    val on get() = screen != null

    fun start(intent: Intent?) {
        val wanted = intent?.getStringExtra("slidePreview") ?: return
        screen = wanted
        intent.getStringExtra("slideLanguage")?.let { L10n.choose(it) }
        val sample = DayStore.days.firstOrNull { it.isSample } ?: run {
            DayStore.save(ch.geneve.slide.logic.SampleDay.make())
            DayStore.days.first { it.isSample }
        }
        tab = when (wanted) {
            "map" -> 1
            "history", "day" -> 2
            "freestyle", "trick" -> 3
            "voice" -> 4
            "profile" -> 5
            else -> 0
        }
        if (wanted == "day") day = sample.id
        if (wanted == "trick") trick = "backflip"
    }

    val samples by lazy { DayStore.read(DayStore.days.first { it.isSample }.id)?.samples ?: emptyList() }
}
