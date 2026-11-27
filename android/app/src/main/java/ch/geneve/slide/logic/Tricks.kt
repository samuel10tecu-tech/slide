package ch.geneve.slide.logic

/** The offline freestyle course, same entries as the iOS TrickLibrary. Text comes from the strings `trick_<id>_…`. */
data class Trick(
    val id: String,
    val level: Level,
    val category: String,
    val stepCount: Int,
    val tipCount: Int,
    val requiresCoach: Boolean,
) {
    enum class Course(val key: String) { BEGINNER("beginner"), PARK("park"), ADVANCED("advanced") }

    enum class Level(val key: String, val course: Course) {
        DEBUTANT("debutant", Course.BEGINNER),
        INTERMEDIAIRE("intermediaire", Course.PARK),
        AVANCE("avance", Course.ADVANCED),
        EXPERT("expert", Course.ADVANCED),
    }
}

object TrickLibrary {
    private fun t(id: String, level: Trick.Level, category: String, steps: Int = 5, tips: Int = 2, coach: Boolean = false) =
        Trick(id, level, category, steps, tips, coach)

    val tricks: List<Trick> = listOf(
        t("park-rules", Trick.Level.DEBUTANT, "securite"),
        t("protections", Trick.Level.DEBUTANT, "securite", steps = 4),
        t("fall-better", Trick.Level.DEBUTANT, "securite", steps = 4),
        t("read-jump", Trick.Level.DEBUTANT, "sauts"),
        t("straight-air", Trick.Level.DEBUTANT, "sauts"),
        t("landing", Trick.Level.DEBUTANT, "reception"),
        t("ollie", Trick.Level.DEBUTANT, "pop"),
        t("safety-grab", Trick.Level.DEBUTANT, "grabs"),
        t("box-5050", Trick.Level.DEBUTANT, "rails"),
        t("one-eighty", Trick.Level.INTERMEDIAIRE, "rotations"),
        t("switch-riding", Trick.Level.INTERMEDIAIRE, "switchRiding"),
        t("nollie", Trick.Level.INTERMEDIAIRE, "pop"),
        t("mute", Trick.Level.INTERMEDIAIRE, "grabs"),
        t("three-sixty", Trick.Level.INTERMEDIAIRE, "rotations"),
        t("nose-butter", Trick.Level.INTERMEDIAIRE, "butters"),
        t("tail-butter", Trick.Level.INTERMEDIAIRE, "butters"),
        t("rail-5050", Trick.Level.INTERMEDIAIRE, "rails"),
        t("absorb", Trick.Level.INTERMEDIAIRE, "reception"),
        t("slide", Trick.Level.AVANCE, "rails"),
        t("japan", Trick.Level.AVANCE, "grabs"),
        t("switch-180", Trick.Level.AVANCE, "switchRiding"),
        t("five-forty", Trick.Level.EXPERT, "rotations", coach = true),
        t("inversion-order", Trick.Level.EXPERT, "securite", coach = true),
        t("backflip", Trick.Level.EXPERT, "sauts", steps = 6, tips = 3, coach = true),
        t("frontflip", Trick.Level.EXPERT, "sauts", steps = 6, tips = 3, coach = true),
        t("cork-360", Trick.Level.EXPERT, "rotations", steps = 6, coach = true),
    )

    fun trick(id: String) = tricks.firstOrNull { it.id == id }
}
