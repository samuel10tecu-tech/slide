import MapKit
import SwiftUI
import UIKit

enum SpeedLineStyle {
    static var colors: [ObjectIdentifier: [UIColor]] = [:]
}

extension TrackGeometry {
    /// One continuous stroke per descent or gap, from the stored points.
    static func strokes(_ samples: [TrackSample]) -> [[TrackSample]] {
        let light = smooth(samples, minMeters: 2)
        guard light.count >= 2 else { return [] }
        var groups: [[TrackSample]] = []
        var current: [TrackSample] = [light[0]]
        for sample in light.dropFirst() {
            let last = current[current.count - 1]
            let moved = Geo.haversineMeters(lat1: last.latitude, lon1: last.longitude, lat2: sample.latitude, lon2: sample.longitude)
            let gap = sample.time.timeIntervalSince(last.time)
            let endedRun = last.phase == .skiing && sample.phase != .skiing
            if moved > 70 || gap > 25 || endedRun {
                if current.count >= 2 { groups.append(current) }
                current = [sample]
            } else {
                current.append(sample)
            }
        }
        if current.count >= 2 { groups.append(current) }
        return groups
    }

    static func gradientLine(_ samples: [TrackSample], dayMaxKmh: Double?) -> MKPolyline? {
        guard samples.count >= 2 else { return nil }
        let coords = samples.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let line: MKPolyline = coords.withUnsafeBufferPointer { buffer in
            MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
        }
        SpeedLineStyle.colors[ObjectIdentifier(line)] = samples.map { sample in
            let rgb = SpeedPaint.rgb(sample.speed, dayMaxKmh: dayMaxKmh)
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
        return line
    }

    static func gradientRenderer(for line: MKPolyline) -> MKOverlayRenderer? {
        guard let colors = SpeedLineStyle.colors[ObjectIdentifier(line)], colors.count >= 2 else { return nil }
        let renderer = MKGradientPolylineRenderer(overlay: line)
        renderer.setColors(colors, locations: gradientStops(line, count: colors.count))
        renderer.lineWidth = 6
        renderer.lineJoin = .round
        renderer.lineCap = .round
        return renderer
    }

    private static func gradientStops(_ line: MKPolyline, count: Int) -> [CGFloat] {
        let points = line.points()
        let pointCount = line.pointCount
        guard pointCount == count, pointCount > 1 else {
            let last = CGFloat(max(count - 1, 1))
            return (0..<count).map { CGFloat($0) / last }
        }
        var walked: [CGFloat] = [0]
        var total: CGFloat = 0
        for index in 1..<pointCount {
            let dx = points[index].x - points[index - 1].x
            let dy = points[index].y - points[index - 1].y
            total += CGFloat(sqrt(dx * dx + dy * dy))
            walked.append(total)
        }
        guard total > 0 else {
            let last = CGFloat(count - 1)
            return (0..<count).map { CGFloat($0) / last }
        }
        var stops = walked.map { $0 / total }
        for index in 1..<stops.count where stops[index] <= stops[index - 1] {
            stops[index] = min(1, stops[index - 1] + 0.000_001)
        }
        stops[stops.count - 1] = 1
        return stops
    }
}

struct GradientTrackMap: UIViewRepresentable {
    var samples: [TrackSample]
    var follow: Bool
    var userCoordinate: CLLocationCoordinate2D?
    var replay: CLLocationCoordinate2D?
    var dayMaxKmh: Double?
    var onSelect: ((TrackSample) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.overrideUserInterfaceStyle = .dark
        if #available(iOS 16.0, *) {
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            map.preferredConfiguration = config
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.samples = samples
        context.coordinator.onSelect = onSelect
        for overlay in map.overlays {
            SpeedLineStyle.colors.removeValue(forKey: ObjectIdentifier(overlay))
        }
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        for group in TrackGeometry.strokes(samples) {
            if let line = TrackGeometry.gradientLine(group, dayMaxKmh: dayMaxKmh) {
                map.addOverlay(line)
            }
        }
        if let replay {
            let pin = MKPointAnnotation()
            pin.coordinate = replay
            map.addAnnotation(pin)
        }
        if follow, let userCoordinate {
            let camera = MKMapCamera(lookingAtCenter: userCoordinate, fromDistance: 900, pitch: 50, heading: 0)
            map.setCamera(camera, animated: true)
        } else if !context.coordinator.didFit, let region = TrackGeometry.region(for: samples) {
            map.setRegion(region, animated: false)
            context.coordinator.didFit = true
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var samples: [TrackSample] = []
        var onSelect: ((TrackSample) -> Void)?
        var didFit = false
        init(onSelect: ((TrackSample) -> Void)?) { self.onSelect = onSelect }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline, let renderer = TrackGeometry.gradientRenderer(for: line) {
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            var best: (TrackSample, CGFloat)?
            let strideBy = max(1, samples.count / 400)
            var index = 0
            while index < samples.count {
                let sample = samples[index]
                let projected = map.convert(CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude), toPointTo: map)
                let distance = hypot(projected.x - point.x, projected.y - point.y)
                if best == nil || distance < best!.1 { best = (sample, distance) }
                index += strideBy
            }
            if let best, best.1 < 48 { onSelect?(best.0) }
        }
    }
}

extension TrackGeometry {
    /// Keeps the shape and the fast points, and drops the points that sit on a straight line.
    static func smooth(_ samples: [TrackSample], minMeters: Double = 2) -> [TrackSample] {
        guard samples.count > 3 else { return samples }
        var kept: [TrackSample] = [samples[0]]
        for sample in samples.dropFirst().dropLast() {
            let last = kept[kept.count - 1]
            let moved = Geo.haversineMeters(lat1: last.latitude, lon1: last.longitude, lat2: sample.latitude, lon2: sample.longitude)
            let burst = sample.speed > last.speed + 2
            if moved >= minMeters || burst { kept.append(sample) }
        }
        kept.append(samples[samples.count - 1])
        return kept
    }
}
