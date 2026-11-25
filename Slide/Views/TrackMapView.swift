import MapKit
import SwiftUI

enum TrackGeometry {
    struct Segment: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let band: SpeedBand
    }

    static func segments(from samples: [TrackSample]) -> [Segment] {
        guard samples.count >= 2 else { return [] }
        var result: [Segment] = []
        var band = SpeedBand.forSpeed(samples[1].speed)
        var coordinates = [coordinate(samples[0])]
        var nextID = 0
        for index in 1..<samples.count {
            let nextBand = SpeedBand.forSpeed(samples[index].speed)
            let point = coordinate(samples[index])
            if nextBand != band, coordinates.count >= 2 {
                result.append(Segment(id: nextID, coordinates: coordinates, band: band))
                nextID += 1
                coordinates = [coordinates[coordinates.count - 1] ]
                band = nextBand
            } else if nextBand != band {
                band = nextBand
            }
            coordinates.append(point)
        }
        if coordinates.count >= 2 {
            result.append(Segment(id: nextID, coordinates: coordinates, band: band))
        }
        return result
    }

    static func region(for samples: [TrackSample]) -> MKCoordinateRegion? {
        guard let first = samples.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for sample in samples {
            minLat = min(minLat, sample.latitude)
            maxLat = max(maxLat, sample.latitude)
            minLon = min(minLon, sample.longitude)
            maxLon = max(maxLon, sample.longitude)
        }
        let latDelta = max(0.004, (maxLat - minLat) * 1.45)
        let lonDelta = max(0.004, (maxLon - minLon) * 1.45)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    static func nearest(to point: CGPoint, proxy: MapProxy, samples: [TrackSample]) -> TrackSample? {
        guard !samples.isEmpty else { return nil }
        let strideBy = max(1, samples.count / 500)
        var best: (TrackSample, CGFloat)?
        var index = 0
        while index < samples.count {
            let sample = samples[index]
            let coord = coordinate(sample)
            if let projected = proxy.convert(coord, to: .local) {
                let distance = hypot(projected.x - point.x, projected.y - point.y)
                if best == nil || distance < best!.1 {
                    best = (sample, distance)
                }
            }
            index += strideBy
        }
        guard let best, best.1 < 44 else { return nil }
        return best.0
    }

    static func coordinate(_ sample: TrackSample) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude)
    }
}

struct SpeedLegend: View {
    @AppStorage("slide.speed.relative") private var relative = false
    @Environment(LanguageSettings.self) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(SpeedPaint.stops.enumerated()), id: \.offset) { _, stop in
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: stop.hex)).frame(width: 8, height: 8)
                        Text(stop.kmh == 0 ? "<15" : "\(Int(stop.kmh))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            Toggle(isOn: $relative) {
                Text(language.t("legend.relative"))
                    .font(.caption.weight(.semibold))
            }
            .tint(Theme.accent)
        }
    }
}

struct LiveTrackMap: View {
    var samples: [TrackSample]
    var follow: Bool
    var userCoordinate: CLLocationCoordinate2D?
    var replay: CLLocationCoordinate2D?
    var onSelect: ((TrackSample) -> Void)?
    @AppStorage("slide.speed.relative") private var relative = false

    private var dayMaxKmh: Double? {
        guard relative, let peak = samples.map(\.speed).max(), peak > 1 else { return nil }
        return peak * 3.6
    }

    var body: some View {
        GradientTrackMap(
            samples: samples,
            follow: follow,
            userCoordinate: userCoordinate,
            replay: replay,
            dayMaxKmh: dayMaxKmh,
            onSelect: onSelect
        )
    }
}
