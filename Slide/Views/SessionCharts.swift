import Charts
import SwiftUI

enum ChartSeries {
    static func downsample(_ samples: [TrackSample], maxCount: Int = 280) -> [TrackSample] {
        guard samples.count > maxCount, maxCount > 1 else { return samples }
        let step = Double(samples.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            let cursor = min(samples.count - 1, Int((Double(index) * step).rounded()))
            return samples[cursor]
        }
    }
}

struct SpeedAltitudeChart: View {
    var samples: [TrackSample]
    var prefs: UnitPrefs
    var speedTitle: String
    var altitudeTitle: String

    private var rows: [TrackSample] { ChartSeries.downsample(samples) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(speedTitle)
                .font(.headline)
            Chart(rows) { sample in
                LineMark(
                    x: .value("t", sample.time),
                    y: .value("v", displaySpeed(sample.speed))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }

            Text(altitudeTitle)
                .font(.headline)
            Chart(rows) { sample in
                AreaMark(
                    x: .value("t", sample.time),
                    y: .value("a", displayAltitude(sample.rawAltitude))
                )
                .foregroundStyle(Theme.ice.opacity(0.25))
                LineMark(
                    x: .value("t", sample.time),
                    y: .value("a", displayAltitude(sample.rawAltitude))
                )
                .foregroundStyle(Theme.ice)
            }
            .frame(height: 140)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private func displaySpeed(_ metersPerSecond: Double) -> Double {
        prefs.speedMetric ? Units.kmh(fromMps: metersPerSecond) : Units.mph(fromMps: metersPerSecond)
    }

    private func displayAltitude(_ meters: Double) -> Double {
        prefs.altitudeMetric ? meters : Units.feet(fromMeters: meters)
    }
}

struct RunBarChart: View {
    var runs: [RunRecord]
    var prefs: UnitPrefs
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if runs.isEmpty {
                Text("—")
                    .foregroundStyle(Theme.muted)
            } else {
                Chart(runs) { run in
                    BarMark(
                        x: .value("run", run.index),
                        y: .value("speed", display(run.maxSpeed))
                    )
                    .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(run.maxSpeed)))
                    .cornerRadius(6)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: runs.map(\.index))
                }
            }
        }
    }

    private func display(_ metersPerSecond: Double) -> Double {
        prefs.speedMetric ? Units.kmh(fromMps: metersPerSecond) : Units.mph(fromMps: metersPerSecond)
    }
}
