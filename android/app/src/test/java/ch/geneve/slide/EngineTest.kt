package ch.geneve.slide

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineTest {
    private val start = 1_763_000_000_000L
    private val metresPerDegree = 111_195.0

    /** One fix per second, moving north at [speed] m/s and changing altitude by [climb] m/s. */
    private fun leg(from: Sample?, seconds: Int, speed: Double, climb: Double): List<Sample> {
        var t = from?.t ?: start
        var lat = from?.lat ?: 46.1
        var alt = from?.alt ?: 2200.0
        return (1..seconds).map {
            t += 1000
            lat += speed / metresPerDegree
            alt += climb
            Sample(t, lat, 7.0, alt, speed)
        }
    }

    private fun descent(): List<Sample> {
        val rest = leg(null, 10, 0.0, 0.0)
        return rest + leg(rest.last(), 60, 12.0, -3.0)
    }

    private fun run(samples: List<Sample>) = Engine().apply { samples.forEach { add(it) } }

    @Test
    fun descentThenRestIsOneRun() {
        val ride = descent()
        val samples = ride + leg(ride.last(), 20, 0.0, 0.0)
        val engine = run(samples)
        assertEquals(1, engine.runs.size)
        assertTrue("distance ${engine.distance}", engine.distance in 600.0..760.0)
        assertTrue("vertical ${engine.vertical}", engine.vertical in 150.0..190.0)
    }

    @Test
    fun stopInTheMiddleOfADescentStillCountsTheRun() {
        val engine = run(descent())
        assertEquals(0, engine.runs.size)
        engine.finish()
        assertEquals(1, engine.runs.size)
    }

    @Test
    fun tinyMovementIsNotARun() {
        val rest = leg(null, 10, 0.0, 0.0)
        val engine = run(rest + leg(rest.last(), 4, 3.0, -0.5))
        engine.finish()
        assertEquals(0, engine.runs.size)
    }

    @Test
    fun gpsSpikeDoesNotBecomeMaxSpeed() {
        val ride = descent().toMutableList()
        val spike = ride[40]
        ride[40] = spike.copy(speed = 90.0)
        val engine = run(ride)
        engine.finish()
        assertEquals(12.0, engine.maxSpeed, 0.001)
        assertEquals(12.0, engine.runs.single().max, 0.001)
    }

    @Test
    fun replayAfterRestartMatchesLiveTracking() {
        val ride = descent()
        val samples = ride + leg(ride.last(), 20, 0.0, 0.0)
        val live = run(samples)
        val rebuilt = Engine().apply { replay(samples) }
        assertEquals(live.runs.size, rebuilt.runs.size)
        assertEquals(live.distance, rebuilt.distance, 0.001)
        assertEquals(live.vertical, rebuilt.vertical, 0.001)
        assertEquals(live.maxSpeed, rebuilt.maxSpeed, 0.001)
    }
}
