package ch.geneve.slide.data

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Locale

/** In-app language, like the iOS LanguageSettings: System or one of 14 languages, independent of the phone. */
object L10n {
    val choices = listOf(
        "system" to "", "en" to "English", "fr" to "Français", "de" to "Deutsch", "it" to "Italiano",
        "es" to "Español", "pt" to "Português", "nl" to "Nederlands", "sv" to "Svenska", "nb" to "Norsk",
        "pl" to "Polski", "cs" to "Čeština", "ja" to "日本語", "ko" to "한국어", "zh-Hans" to "简体中文",
    )
    private const val KEY = "slide.language"
    private val supported = setOf("en", "fr", "de", "it", "es", "pt", "nl", "sv", "nb", "pl", "cs", "ja", "ko")

    var choice by mutableStateOf("system")
        private set
    private lateinit var app: Context
    private var resources: Resources? = null
    private var resourcesCode = ""
    private val ids = HashMap<String, Int>()

    fun init(context: Context) {
        app = context.applicationContext
        choice = Prefs.get(app).getString(KEY, "system") ?: "system"
    }

    fun choose(value: String) {
        choice = value
        Prefs.get(app).edit().putString(KEY, value).apply()
    }

    val code: String
        get() = if (choice != "system") choice else matching(Locale.getDefault())

    /** Comma decimals and a narrow space for thousands. English, Japanese, Korean and Chinese use a period. */
    val frenchNumbers: Boolean get() = code !in setOf("en", "ja", "ko", "zh-Hans")

    val locale: Locale
        get() = when (val c = code) {
            "zh-Hans" -> Locale.forLanguageTag("zh-Hans")
            "fr" -> Locale.forLanguageTag("fr-CH")
            "en" -> Locale.UK
            else -> Locale.forLanguageTag(c)
        }

    fun t(key: String): String {
        val res = localized()
        val name = key.replace(Regex("[^A-Za-z0-9_]"), "_")
        val id = ids.getOrPut(name) { res.getIdentifier(name, "string", app.packageName) }
        return if (id == 0) key else res.getString(id)
    }

    fun t(key: String, vararg args: Any): String = String.format(locale, t(key), *args)

    private fun localized(): Resources {
        val wanted = code
        resources?.let { if (resourcesCode == wanted) return it }
        val config = Configuration(app.resources.configuration)
        config.setLocale(locale)
        val res = app.createConfigurationContext(config).resources
        resources = res
        resourcesCode = wanted
        return res
    }

    fun matching(locale: Locale): String {
        val tag = locale.toLanguageTag().lowercase()
        if (tag.startsWith("zh")) return "zh-Hans"
        if (tag.startsWith("nb") || tag.startsWith("nn") || tag.startsWith("no")) return "nb"
        val primary = locale.language.lowercase()
        return if (primary in supported) primary else "en"
    }
}
