package ch.geneve.slide.logic

/** Turns GPS points into phases (descent, lift, rest) and runs. Port of the iOS SessionTracker. */
class SessionTracker(val config: DetectorConfig = DetectorConfig()) {
    private val filter = TrackFilter(config)
    val raw = mutableListOf<GeoSample>()
    var samples: List<TrackSample> = emptyList()
        private set
    var runs: List<RunRecord> = emptyList()
        private set
    var openRun: RunRecord? = null
        private set
    var phase: TrackPhase = TrackPhase.UNKNOWN
        private set
    var rejectedCount = 0
        private set
    private val working = mutableListOf<TrackSample>()
    private var runIds: List<String> = emptyList()

    val summary: LiveSummary
        get() {
            val open = openRun
            val openAlreadyCounted = open != null && runs.any { kotlin.math.abs(it.startedAt - open.startedAt) < 0.5 }
            val pending = if (openAlreadyCounted) null else open
            val distance = runs.sumOf { it.distance } + (pending?.distance ?: 0.0)
            val vertical = runs.sumOf { it.verticalDrop } + (pending?.verticalDrop ?: 0.0)
            val fastest = maxOf(runs.maxOfOrNull { it.maxSpeed } ?: 0.0, pending?.maxSpeed ?: 0.0)
            val last = samples.lastOrNull()
            return LiveSummary(
                speed = last?.speed ?: 0.0,
                altitude = last?.altitude ?: 0.0,
                hasFix = samples.isNotEmpty(),
                phase = phase,
                distance = distance,
                vertical = vertical,
                maxSpeed = fastest,
                qualifiedRuns = runs.size,
                openRun = open,
                accuracy = last?.accuracy ?: -1.0,
            )
        }

    fun ingest(sample: GeoSample): IngestOutcome {
        raw.add(sample)
        return when (val result = filter.push(sample)) {
            is TrackFilter.Result.Rejected -> {
                rejectedCount += 1
                IngestOutcome(false, result.reason, phase, runs.size)
            }
            is TrackFilter.Result.Accepted -> {
                working.add(result.sample.copy(phase = phase))
                rebuildRuns()
                IngestOutcome(true, null, phase, runs.size)
            }
        }
    }

    private fun rebuildRuns() {
        val labels = commitPhases(working, config)
        for (index in working.indices) {
            if (working[index].phase != labels[index]) working[index] = working[index].copy(phase = labels[index])
        }
        samples = working.toList()
        phase = labels.lastOrNull() ?: TrackPhase.UNKNOWN

        val spans = skiingSpans(working, labels, config.maxGap)
        val qualified = mutableListOf<RunRecord>()
        var open: RunRecord? = null
        for (span in spans) {
            val stat = stats(working, span.first, span.second)
            val isQualified = stat.duration >= config.minRunDuration &&
                (stat.distance >= config.minRunDistance || stat.vertical >= config.minRunVertical)
            val isOpen = span.second == working.size - 1 && labels[span.second] == TrackPhase.SKIING
            val recordId = if (isQualified && qualified.size < runIds.size) runIds[qualified.size] else newId()
            val record = RunRecord(
                id = recordId,
                index = qualified.size + 1,
                startedAt = working[span.first].time,
                endedAt = working[span.second].time,
                maxSpeed = stat.maxSpeed,
                avgSpeed = stat.average,
                distance = stat.distance,
                verticalDrop = stat.vertical,
                duration = stat.duration,
            )
            if (isQualified) qualified.add(record)
            if (isOpen) open = record.copy(index = if (isQualified) record.index else qualified.size + 1)
        }
        runs = qualified
        openRun = open
        runIds = qualified.map { it.id }
    }

    data class SpanStats(val distance: Double, val vertical: Double, val maxSpeed: Double, val average: Double, val duration: Double)

    companion object {
        fun replay(samples: List<GeoSample>, config: DetectorConfig = DetectorConfig()): SessionTracker {
            val tracker = SessionTracker(config)
            samples.forEach { tracker.ingest(it) }
            return tracker
        }

        fun commitPhases(samples: List<TrackSample>, config: DetectorConfig): List<TrackPhase> {
            val labels = MutableList(samples.size) { TrackPhase.UNKNOWN }
            var current = TrackPhase.UNKNOWN
            var candidate: TrackPhase? = null
            var candidateStart = 0
            for (index in samples.indices) {
                if (index > 0 && samples[index].time - samples[index - 1].time > config.maxGap) {
                    current = TrackPhase.UNKNOWN
                    candidate = null
                }
                val raw = rawPhase(samples, index, config)
                if (raw == null) {
                    labels[index] = current
                    continue
                }
                if (raw == current) {
                    labels[index] = current
                    candidate = null
                    continue
                }
                if (candidate != raw) {
                    candidate = raw
                    candidateStart = index
                }
                val elapsed = samples[index].time - samples[candidateStart].time
                if (elapsed >= config.hold) {
                    for (cursor in candidateStart..index) labels[cursor] = raw
                    current = raw
                    candidate = null
                } else {
                    labels[index] = current
                }
            }
            return labels
        }

        fun rawPhase(samples: List<TrackSample>, index: Int, config: DetectorConfig): TrackPhase? {
            val endTime = samples[index].time
            var start = index
            while (start > 0 && endTime - samples[start - 1].time <= config.trendWindow) start -= 1
            val span = endTime - samples[start].time
            if (span < config.minTrendSpan) return null
            val rate = (samples[index].altitude - samples[start].altitude) / span
            var sum = 0.0
            for (cursor in start..index) sum += samples[cursor].speed
            val speed = sum / (index - start + 1)
            return classify(rate, speed, config)
        }

        fun classify(rate: Double, speed: Double, config: DetectorConfig): TrackPhase = when {
            speed < config.restSpeed && rate < config.liftRate -> TrackPhase.REST
            rate >= config.liftRate && speed >= config.liftMinSpeed && speed <= config.liftMaxSpeed -> TrackPhase.LIFT
            speed >= config.skiSpeed && rate < config.liftRate -> TrackPhase.SKIING
            else -> TrackPhase.REST
        }

        /** Consecutive skiing samples, cut at GPS gaps. Pairs of (start, end) indices. */
        fun skiingSpans(samples: List<TrackSample>, labels: List<TrackPhase>, maxGap: Double): List<Pair<Int, Int>> {
            val spans = mutableListOf<Pair<Int, Int>>()
            var index = 0
            while (index < labels.size) {
                if (labels[index] != TrackPhase.SKIING) {
                    index += 1
                    continue
                }
                val start = index
                var end = index
                while (end + 1 < labels.size && labels[end + 1] == TrackPhase.SKIING) {
                    if (samples[end + 1].time - samples[end].time > maxGap) break
                    end += 1
                }
                spans.add(start to end)
                index = end + 1
            }
            return spans
        }

        fun stats(samples: List<TrackSample>, start: Int, end: Int): SpanStats {
            val duration = samples[end].time - samples[start].time
            var distance = 0.0
            var vertical = 0.0
            var maxSpeed = samples[start].speed
            for (index in start + 1..end) {
                distance += samples[index].segmentDistance
                val drop = samples[index - 1].rawAltitude - samples[index].rawAltitude
                if (drop > 0) vertical += drop
                maxSpeed = maxOf(maxSpeed, samples[index].speed)
            }
            val average = if (duration > 0.5) distance / duration else 0.0
            return SpanStats(distance, vertical, maxSpeed, average, maxOf(0.0, duration))
        }
    }
}
