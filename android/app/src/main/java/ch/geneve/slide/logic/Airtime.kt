package ch.geneve.slide.logic

/**
 * Estimates flight time when the accelerometer drops near 0 g and comes back.
 * Not an exact measure: the phone moves in a pocket. Port of the iOS AirtimeDetector.
 */
class AirtimeDetector(
    private val lowG: Double = 0.42,
    private val highG: Double = 0.72,
    private val minDuration: Double = 0.18,
    private val maxDuration: Double = 3.2,
) {
    private var belowSince: Double? = null
    private var startedArmed = false

    fun reset() {
        belowSince = null
        startedArmed = false
    }

    /** Returns the flight duration in seconds when a jump ends. */
    fun ingest(time: Double, magnitudeG: Double, armed: Boolean): Double? {
        if (!magnitudeG.isFinite() || !time.isFinite()) return null
        if (magnitudeG < lowG) {
            if (belowSince == null) {
                belowSince = time
                startedArmed = armed
            }
            return null
        }
        val start = belowSince
        if (magnitudeG < highG || start == null) return null
        belowSince = null
        val duration = time - start
        if (!startedArmed || duration < minDuration || duration > maxDuration) return null
        return duration
    }
}
