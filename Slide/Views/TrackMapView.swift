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
    var body: some View {
        HStack(spacing: 8) {
            ForEach(SpeedBand.allCases, id: \.rawValue) { band in
                HStack(spacing: 4) {
                    Circle().fill(Theme.color(for: band)).frame(width: 8, height: 8)
                    Text(legend(band))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func legend(_ band: SpeedBand) -> String {
        switch band {
        case .slow: return "<20"
        case .cruise: return "20"
        case .fast: return "40"
        case .flying: return "60"
        case .extreme: return "80+"
        }
    }
}

struct LiveTrackMap: View {
    var samples: [TrackSample]
    var follow: Bool
    var userCoordinate: CLLocationCoordinate2D?
    var replay: CLLocationCoordinate2D?
    var onSelect: ((TrackSample) -> Void)?

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()
                ForEach(TrackGeometry.segments(from: samples)) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(Theme.color(for: segment.band), lineWidth: 5)
                }
                if let replay {
                    Annotation("replay", coordinate: replay) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.hybrid())
            .onTapGesture { location in
                guard let sample = TrackGeometry.nearest(to: location, proxy: proxy, samples: samples) else { return }
                onSelect?(sample)
            }
        }
        .onChange(of: followToken) { _, _ in
            recenter()
        }
        .onAppear { recenter() }
    }

    private var followToken: String {
        guard follow, let userCoordinate else { return "idle" }
        return "\(userCoordinate.latitude),\(userCoordinate.longitude)"
    }

    private func recenter() {
        if follow, let userCoordinate {
            position = .camera(MapCamera(centerCoordinate: userCoordinate, distance: 900, heading: 0, pitch: 45))
        } else if let region = TrackGeometry.region(for: samples) {
            position = .region(region)
        }
    }
}
