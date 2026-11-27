package ch.geneve.slide.logic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.hypot

/** The iOS LogicChecks, ported one by one. Both apps must agree on runs, distance and file formats. */
class LogicParityTest {
    private val start = 1_700_000_000.0

    private class Lcg(var state: ULong) {
        fun unit(): Double {
            state = state * 6_364_136_223_846_793_005uL + 1uL
            return (state shr 11).toDouble() / (1uL shl 53).toDouble()
        }
    }

    private class Trace(var time: Double, var lat: Double, var lon: Double, var alt: Double) {
        val samples = mutableListOf<GeoSample>()

        fun leg(seconds: Int, north: Double, east: Double = 0.0, vertical: Double, accuracy: Double = 4.0, gpsSpeed: Double? = null) {
            val first = if (samples.isEmpty()) 0 else 1
            for (index in first..seconds) {
                val (mLat, mLon) = Geo.project(lat, lon, north * index, east * index)
                samples.add(GeoSample(time + index, mLat, mLon, alt + vertical * index, accuracy, gpsSpeed ?: hypot(north, east)))
            }
            val last = samples.last()
            lat = last.latitude
            lon = last.longitude
            alt = last.altitude
            time = last.time
        }
    }

    @Test fun haversineLatitudeDegree() = assertEquals(111_195.0, Geo.haversineMeters(0.0, 0.0, 1.0, 0.0), 50.0)

    @Test fun projectRoundTrip() {
        val (lat, lon) = Geo.project(46.2, 6.15, 1_000.0, -250.0)
        assertEquals(hypot(1_000.0, 250.0), Geo.haversineMeters(46.2, 6.15, lat, lon), 3.0)
    }

    @Test fun rejectsBadAccuracy() {
        val trace = Trace(start, 46.2, 6.15, 1_500.0)
        trace.leg(8, north = 8.0, vertical = -1.0)
        val count = trace.samples.size
        trace.samples.add(GeoSample(trace.time + 1, trace.lat + 0.01, trace.lon, trace.alt, 80.0, 8.0))
        val tracker = SessionTracker.replay(trace.samples)
        assertTrue(tracker.rejectedCount >= 1)
        assertEquals(count, tracker.samples.size)
    }

    @Test fun rejectsNonFiniteAndTimeRegression() {
        val nan = TrackFilter().push(GeoSample(10.0, Double.NaN, 6.0, 10.0, 5.0))
        assertEquals(TrackFilter.Result.Rejected(RejectReason.NON_FINITE), nan)
        val filter = TrackFilter()
        filter.push(GeoSample(start, 46.0, 6.0, 1000.0, 5.0, 0.0))
        assertEquals(
            TrackFilter.Result.Rejected(RejectReason.TIME_WENT_BACKWARDS),
            filter.push(GeoSample(start - 2, 46.0001, 6.0, 999.0, 5.0, 5.0)),
        )
    }

    @Test fun speedSpikeAddsNoDistance() {
        val trace = Trace(start, 46.2, 6.15, 1_800.0)
        trace.leg(20, north = 10.0, vertical = -1.2)
        val raw = trace.samples.toMutableList()
        val original = raw[10]
        raw[10] = original.copy(latitude = original.latitude + 0.02, longitude = original.longitude + 0.01, horizontalAccuracy = 6.0, gpsSpeed = 120.0)
        val tracker = SessionTracker.replay(raw)
        val distance = tracker.summary.distance
        assertTrue("distance $distance", distance < 350 && distance > 120)
        assertTrue(tracker.rejectedCount >= 1)
    }

    @Test fun jitterDoesNotInflateDistance() {
        val rng = Lcg(42u)
        val samples = (0 until 70).map { index ->
            val north = (rng.unit() - 0.5) * 6
            val east = (rng.unit() - 0.5) * 6
            val (lat, lon) = Geo.project(46.2, 6.8, north, east)
            GeoSample(start + index, lat, lon, 1_500 + (rng.unit() - 0.5) * 2, 15.0, 0.0)
        }
        val tracker = SessionTracker.replay(samples)
        assertTrue(tracker.runs.isEmpty())
        assertTrue("distance ${tracker.summary.distance}", tracker.summary.distance < 40)
    }

    @Test fun gapDoesNotDrawStraightLine() {
        val trace = Trace(start, 46.2, 6.15, 1_600.0)
        trace.leg(15, north = 10.0, vertical = -1.4)
        val (lat, lon) = Geo.project(trace.lat, trace.lon, 3_000.0, 400.0)
        trace.samples.add(GeoSample(trace.time + 120, lat, lon, trace.alt - 10, 5.0, 0.0))
        assertTrue(SessionTracker.replay(trace.samples).summary.distance < 400)
    }

    @Test fun cleanDescentIsOneRun() {
        val trace = Trace(start, 46.19, 6.84, 2_000.0)
        trace.leg(40, north = 12.0, vertical = -2.0)
        val tracker = SessionTracker.replay(trace.samples)
        val summary = tracker.summary
        assertEquals(1, tracker.runs.size)
        assertTrue("distance ${summary.distance}", summary.distance > 320 && summary.distance < 520)
        assertTrue("vertical ${summary.vertical}", summary.vertical > 55 && summary.vertical < 85)
        assertTrue(summary.maxSpeed > 11)
        val run = tracker.runs[0]
        assertTrue("avg ${run.avgSpeed}", run.avgSpeed > 8 && run.avgSpeed < 14)
        assertTrue("duration ${run.duration}", run.duration > 25 && run.duration <= 40)
    }

    @Test fun descentLiftDescentIsTwoRuns() {
        val trace = Trace(start, 46.19, 6.84, 2_000.0)
        trace.leg(35, north = 12.0, vertical = -2.1)
        trace.leg(18, north = 0.0, vertical = 0.0, gpsSpeed = 0.0)
        trace.leg(30, north = -4.0, vertical = 1.6, gpsSpeed = 4.0)
        trace.leg(16, north = 0.0, vertical = 0.0, gpsSpeed = 0.0)
        trace.leg(32, north = 11.0, east = 2.0, vertical = -1.8)
        val tracker = SessionTracker.replay(trace.samples)
        assertEquals(2, tracker.runs.size)
        assertTrue(tracker.runs[0].maxSpeed > 10)
        assertTrue(tracker.runs[1].maxSpeed > 9)
        assertTrue(tracker.summary.vertical > 70)
    }

    @Test fun liftAloneIsNotARun() {
        val trace = Trace(start, 46.2, 6.8, 1_400.0)
        trace.leg(50, north = 4.0, vertical = 1.5, gpsSpeed = 4.2)
        val tracker = SessionTracker.replay(trace.samples)
        assertTrue(tracker.runs.isEmpty())
        assertEquals(TrackPhase.LIFT, tracker.phase)
    }

    @Test fun shortBurstAndStationary() {
        val burst = Trace(start, 46.2, 6.8, 1_500.0)
        burst.leg(6, north = 8.0, vertical = -1.0)
        assertTrue(SessionTracker.replay(burst.samples).runs.isEmpty())
        val still = Trace(start, 46.2, 6.8, 1_200.0)
        still.leg(25, north = 0.0, vertical = 0.0, gpsSpeed = 0.0)
        val tracker = SessionTracker.replay(still.samples)
        assertEquals(TrackPhase.REST, tracker.phase)
        assertTrue(tracker.summary.distance < 5)
    }

    @Test fun noisyDescentStillOneRun() {
        val rng = Lcg(7u)
        var lat = 46.19
        var lon = 6.84
        var alt = 1_900.0
        val samples = (0..45).map { index ->
            val (mLat, mLon) = Geo.project(lat, lon, 12 + (rng.unit() - 0.5) * 3, (rng.unit() - 0.5) * 3)
            lat = mLat
            lon = mLon
            alt += -2 + (rng.unit() - 0.5) * 1.2
            GeoSample(start + index, lat, lon, alt, 6.0, 12.0)
        }
        val tracker = SessionTracker.replay(samples)
        assertEquals(1, tracker.runs.size)
        assertTrue(tracker.summary.distance > 300)
        assertTrue(tracker.summary.vertical > 40)
    }

    @Test fun airtime() {
        val detector = AirtimeDetector()
        var hit: Double? = null
        for (step in 0..20) {
            val time = step * 0.05
            detector.ingest(time, if (time >= 0.2 && time < 0.62) 0.15 else 1.0, true)?.let { hit = it }
        }
        assertTrue("hit $hit", hit != null && hit!! > 0.3 && hit!! < 0.55)

        val unarmed = AirtimeDetector()
        var none: Double? = null
        for (step in 0..20) {
            val time = step * 0.05
            none = unarmed.ingest(time, if (time >= 0.2 && time < 0.7) 0.1 else 1.0, false) ?: none
        }
        assertNull(none)
    }

    @Test fun gpxRoundTrip() {
        val trace = Trace(start, 46.204, 6.143, 1_200.0)
        trace.leg(25, north = 11.0, east = -2.0, vertical = -1.6)
        val tracker = SessionTracker.replay(trace.samples)
        val archive = SessionArchive(
            id = newId(), startedAt = start, endedAt = trace.time, resort = "Salève & Genève", riderName = "Sam",
            isComplete = true, isSample = false, raw = tracker.raw.toList(), samples = tracker.samples, runs = tracker.runs,
            jumps = emptyList(), maxSpeed = tracker.summary.maxSpeed, distance = tracker.summary.distance,
            vertical = tracker.summary.vertical, duration = 25.0,
        )
        val xml = GpxCodec.encode(archive)
        assertTrue(xml.contains("Salève") && xml.contains("&amp;"))
        val parsed = GpxCodec.parse(xml, start)
        assertEquals(tracker.samples.size, parsed.size)
        assertEquals(tracker.samples[0].latitude, parsed[0].latitude, 0.000001)
        assertEquals(tracker.runs.size, SessionTracker.replay(parsed).runs.size)
    }

    @Test fun sessionFileRoundTripKeepsFractions() {
        val archive = SampleDay.make(1_763_000_000.25)
        val decoded = SessionFile.decode(SessionFile.encode(archive))
        assertEquals(archive.runs.size, decoded.runs.size)
        assertEquals(archive.jumps.size, decoded.jumps.size)
        assertEquals(archive.distance, decoded.distance, 0.01)
        assertEquals(archive.samples.size, decoded.samples.size)
        assertEquals(archive.raw[1].time, decoded.raw[1].time, 0.002)
    }

    @Test fun sampleDayHasSeveralRuns() {
        val archive = SampleDay.make(1_763_000_000.0)
        assertTrue(archive.isSample)
        assertTrue("runs ${archive.runs.size}", archive.runs.size >= 4)
    }

    @Test fun seasonBoundaries() {
        val zone = ZoneId.systemDefault()
        fun at(y: Int, m: Int, d: Int) = LocalDate.of(y, m, d).atTime(12, 0).atZone(zone).toEpochSecond().toDouble()
        assertEquals("2026–2027", Season.containing(at(2026, 11, 25)).title)
        assertEquals("2025–2026", Season.containing(at(2026, 3, 2)).title)
        assertEquals("2026–2027", Season.containing(at(2026, 9, 1)).title)
        assertEquals("2025–2026", Season.containing(at(2026, 8, 31)).title)
    }

    @Test fun speedBands() {
        assertEquals(SpeedBand.SLOW, SpeedBand.forSpeed(10 / 3.6))
        assertEquals(SpeedBand.CRUISE, SpeedBand.forSpeed(35 / 3.6))
        assertEquals(SpeedBand.FAST, SpeedBand.forSpeed(50 / 3.6))
        assertEquals(SpeedBand.FLYING, SpeedBand.forSpeed(70 / 3.6))
        assertEquals(SpeedBand.EXTREME, SpeedBand.forSpeed(90 / 3.6))
    }

    @Test fun formats() {
        assertEquals("0:00", Fmt.duration(0.0))
        assertEquals("1:05", Fmt.duration(65.0))
        assertEquals("1:01:01", Fmt.duration(3_661.0))
        assertEquals("1 234,6", Fmt.decimal(1234.56, 1))
        assertEquals("36,0", Fmt.speed(10.0, UnitPrefs.METRIC, true))
        assertEquals("840 m", Fmt.distance(840.0, UnitPrefs.METRIC, true))
        assertEquals("4,2 km", Fmt.distance(4_200.0, UnitPrefs.METRIC, true))
        assertEquals("1,234.6", Fmt.decimal(1234.56, 1, french = false))
        assertEquals("36.0", Fmt.speed(10.0, UnitPrefs.METRIC, false))
    }

    @Test fun resortIndex() {
        assertEquals("Les Crosets", ResortIndex.match(46.184, 6.842)?.name)
        assertNull(ResortIndex.match(0.0, 0.0))
    }

    /** A day exported by the iPhone app (tooling/make_ios_fixture.swift) must open on Android. */
    @Test fun readsAnIosSlideFile() {
        val text = javaClass.getResource("/ios-sample.slide")!!.readText()
        val archive = SessionFile.decode(text)
        assertTrue(archive.isSample)
        assertTrue(archive.runs.size >= 4)
        assertEquals("Les Crosets", archive.resort)
        val rebuilt = SessionTracker.replay(archive.raw)
        assertEquals(archive.runs.size, rebuilt.runs.size)
        assertEquals(archive.distance, rebuilt.summary.distance, 1.0)
    }
}
