import Foundation

/// Transforme des points GPS en phases (descente, remontée, repos) et en descentes.
struct SessionTracker {
    var config: DetectorConfig
    private var filter: TrackFilter
    private(set) var raw: [GeoSample] = []
    private(set) var samples: [TrackSample] = []
    private(set) var runs: [RunRecord] = []
    private(set) var openRun: RunRecord?
    private(set) var phase: TrackPhase = .unknown
    private(set) var rejectedCount = 0
    private var runIDs: [UUID] = []

    init(config: DetectorConfig = DetectorConfig()) {
        self.config = config
        self.filter = TrackFilter(config: config)
    }

    var summary: LiveSummary {
        let openAlreadyCounted = openRun.map { open in
            runs.contains { abs($0.startedAt.timeIntervalSince(open.startedAt)) < 0.5 }
        } ?? false
        let pending = openAlreadyCounted ? nil : openRun
        let distance = runs.reduce(0) { $0 + $1.distance } + (pending?.distance ?? 0)
        let vertical = runs.reduce(0) { $0 + $1.verticalDrop } + (pending?.verticalDrop ?? 0)
        let fastest = max(runs.map(\.maxSpeed).max() ?? 0, pending?.maxSpeed ?? 0)
        return LiveSummary(
            speed: samples.last?.speed ?? 0,
            altitude: samples.last?.altitude ?? 0,
            hasFix: !samples.isEmpty,
            phase: phase,
            distance: distance,
            vertical: vertical,
            maxSpeed: fastest,
            qualifiedRuns: runs.count,
            openRun: openRun,
            accuracy: samples.last?.accuracy ?? -1
        )
    }

    mutating func ingest(_ sample: GeoSample) -> IngestOutcome {
        raw.append(sample)
        switch filter.push(sample) {
        case .failure(let reason):
            rejectedCount += 1
            return IngestOutcome(accepted: false, reason: reason, phase: phase, qualifiedRuns: runs.count)
        case .success(var accepted):
            accepted.phase = phase
            samples.append(accepted)
            rebuildRuns()
            return IngestOutcome(accepted: true, reason: nil, phase: phase, qualifiedRuns: runs.count)
        }
    }

    static func replay(_ samples: [GeoSample], config: DetectorConfig = DetectorConfig()) -> SessionTracker {
        var tracker = SessionTracker(config: config)
        for sample in samples {
            _ = tracker.ingest(sample)
        }
        return tracker
    }

    private mutating func rebuildRuns() {
        let labels = Self.commitPhases(samples: samples, config: config)
        for index in samples.indices {
            samples[index].phase = labels[index]
        }
        phase = labels.last ?? .unknown

        let spans = Self.skiingSpans(samples: samples, labels: labels, maxGap: config.maxGap)
        var qualified: [RunRecord] = []
        var open: RunRecord?
        for span in spans {
            let stat = Self.stats(samples: samples, start: span.start, end: span.end)
            let isQualified = stat.duration >= config.minRunDuration
                && (stat.distance >= config.minRunDistance || stat.vertical >= config.minRunVertical)
            let isOpen = span.end == samples.count - 1 && labels[span.end] == .skiing
            let recordID: UUID
            if isQualified {
                if qualified.count < runIDs.count {
                    recordID = runIDs[qualified.count]
                } else {
                    recordID = UUID()
                }
            } else {
                recordID = UUID()
            }
            let record = RunRecord(
                id: recordID,
                index: qualified.count + 1,
                startedAt: samples[span.start].time,
                endedAt: samples[span.end].time,
                maxSpeed: stat.maxSpeed,
                avgSpeed: stat.average,
                distance: stat.distance,
                verticalDrop: stat.vertical,
                duration: stat.duration
            )
            if isQualified {
                qualified.append(record)
            }
            if isOpen {
                var shown = record
                shown.index = isQualified ? record.index : qualified.count + 1
                open = shown
            }
        }
        runs = qualified
        openRun = open
        runIDs = qualified.map(\.id)
    }

    static func commitPhases(samples: [TrackSample], config: DetectorConfig) -> [TrackPhase] {
        let count = samples.count
        var labels = Array(repeating: TrackPhase.unknown, count: count)
        var current: TrackPhase = .unknown
        var candidate: TrackPhase?
        var candidateStart = 0

        for index in 0..<count {
            if index > 0 {
                let gap = samples[index].time.timeIntervalSince(samples[index - 1].time)
                if gap > config.maxGap {
                    current = .unknown
                    candidate = nil
                }
            }
            guard let raw = rawPhase(samples: samples, index: index, config: config) else {
                labels[index] = current
                continue
            }
            if raw == current {
                labels[index] = current
                candidate = nil
                continue
            }
            if candidate != raw {
                candidate = raw
                candidateStart = index
            }
            let elapsed = samples[index].time.timeIntervalSince(samples[candidateStart].time)
            if elapsed >= config.hold {
                for cursor in candidateStart...index {
                    labels[cursor] = raw
                }
                current = raw
                candidate = nil
            } else {
                labels[index] = current
            }
        }
        return labels
    }

    static func rawPhase(samples: [TrackSample], index: Int, config: DetectorConfig) -> TrackPhase? {
        let endTime = samples[index].time
        var start = index
        while start > 0 && endTime.timeIntervalSince(samples[start - 1].time) <= config.trendWindow {
            start -= 1
        }
        let span = endTime.timeIntervalSince(samples[start].time)
        guard span >= config.minTrendSpan else { return nil }
        let rate = (samples[index].altitude - samples[start].altitude) / span
        var speedSum = 0.0
        var counted = 0
        for cursor in start...index {
            speedSum += samples[cursor].speed
            counted += 1
        }
        let speed = counted > 0 ? speedSum / Double(counted) : 0
        return classify(rate: rate, speed: speed, config: config)
    }

    static func classify(rate: Double, speed: Double, config: DetectorConfig) -> TrackPhase {
        if speed < config.restSpeed && rate < config.liftRate {
            return .rest
        }
        if rate >= config.liftRate && speed >= config.liftMinSpeed && speed <= config.liftMaxSpeed {
            return .lift
        }
        if speed >= config.skiSpeed && rate < config.liftRate {
            return .skiing
        }
        if speed < config.restSpeed {
            return .rest
        }
        return .rest
    }

    struct Span {
        var start: Int
        var end: Int
    }

    static func skiingSpans(samples: [TrackSample], labels: [TrackPhase], maxGap: TimeInterval) -> [Span] {
        var spans: [Span] = []
        var index = 0
        while index < labels.count {
            guard labels[index] == .skiing else {
                index += 1
                continue
            }
            let start = index
            var end = index
            while end + 1 < labels.count && labels[end + 1] == .skiing {
                let gap = samples[end + 1].time.timeIntervalSince(samples[end].time)
                if gap > maxGap { break }
                end += 1
            }
            spans.append(Span(start: start, end: end))
            index = end + 1
        }
        return spans
    }

    struct SpanStats {
        var distance: Double
        var vertical: Double
        var maxSpeed: Double
        var average: Double
        var duration: TimeInterval
    }

    static func stats(samples: [TrackSample], start: Int, end: Int) -> SpanStats {
        let duration = samples[end].time.timeIntervalSince(samples[start].time)
        var distance = 0.0
        var vertical = 0.0
        var maxSpeed = samples[start].speed
        if end > start {
            for index in (start + 1)...end {
                distance += samples[index].segmentDistance
                let drop = samples[index - 1].rawAltitude - samples[index].rawAltitude
                if drop > 0 {
                    vertical += drop
                }
                maxSpeed = max(maxSpeed, samples[index].speed)
            }
        }
        let average = duration > 0.5 ? distance / duration : 0
        return SpanStats(
            distance: distance,
            vertical: vertical,
            maxSpeed: maxSpeed,
            average: average,
            duration: max(0, duration)
        )
    }
}
