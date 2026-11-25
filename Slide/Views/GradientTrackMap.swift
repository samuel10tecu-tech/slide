import MapKit
import SwiftUI
import UIKit

enum SpeedLineStyle {
    static var colors: [ObjectIdentifier: [UIColor]] = [:]
}

final class SpeedGradientRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let polyline = overlay as? MKPolyline else { return }
        let painted = SpeedLineStyle.colors[ObjectIdentifier(polyline)] ?? []
        let count = polyline.pointCount
        guard count > 1, !painted.isEmpty else { return }
        let points = polyline.points()
        let width = 7 / zoomScale
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for index in 1..<count {
            let start = point(for: points[index - 1])
            let end = point(for: points[index])
            let from = painted[min(index - 1, painted.count - 1)].cgColor
            let to = painted[min(index, painted.count - 1)].cgColor
            context.saveGState()
            context.move(to: start)
            context.addLine(to: end)
            context.replacePathWithStrokedPath()
            context.clip()
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [from, to] as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: start, end: end, options: [])
            }
            context.restoreGState()
        }
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
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        let drawn = TrackGeometry.smooth(samples)
        if drawn.count >= 2 {
            let coords = drawn.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let line: MKPolyline = coords.withUnsafeBufferPointer { buffer in
                MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
            }
            SpeedLineStyle.colors[ObjectIdentifier(line)] = drawn.map { sample in
                let rgb = SpeedPaint.rgb(sample.speed, dayMaxKmh: dayMaxKmh)
                return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            }
            map.addOverlay(line)
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
            if let line = overlay as? MKPolyline, SpeedLineStyle.colors[ObjectIdentifier(line)] != nil {
                return SpeedGradientRenderer(overlay: line)
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
    static func smooth(_ samples: [TrackSample], minMeters: Double = 8) -> [TrackSample] {
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
