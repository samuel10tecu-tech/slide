import MapKit
import SwiftData
import SwiftUI

struct PlacePoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
}

struct PlaceCluster: Identifiable {
    var id: String
    var latitude: Double
    var longitude: Double
    var dayIDs: [UUID]
}

enum PlaceIndex {
    static func clusters(_ points: [PlacePoint], radiusMeters: Double = 8_000) -> [PlaceCluster] {
        var groups: [[PlacePoint]] = []
        for point in points {
            if let index = groups.firstIndex(where: { group in
                group.contains { Geo.haversineMeters(lat1: $0.latitude, lon1: $0.longitude, lat2: point.latitude, lon2: point.longitude) <= radiusMeters }
            }) {
                groups[index].append(point)
            } else {
                groups.append([point])
            }
        }
        return groups.map { group in
            let lat = group.map(\.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.longitude).reduce(0, +) / Double(group.count)
            let ids = group.map(\.id)
            return PlaceCluster(id: ids.map(\.uuidString).joined(separator: "-"), latitude: lat, longitude: lon, dayIDs: ids)
        }
    }
}

struct DrawnTrack: Identifiable {
    var id: UUID
    var samples: [TrackSample]
    var latitude: Double
    var longitude: Double
    var resort: String
    var dayMaxKmh: Double?
}

struct PlacesMapView: View {
    @Environment(LanguageSettings.self) private var language
    @Query(sort: \SkiDay.startedAt, order: .reverse) private var days: [SkiDay]
    @State private var openID: UUID?
    @State private var group: PlaceCluster?
    @State private var tracks: [DrawnTrack] = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                WorldTracksMap(tracks: tracks) { id in
                    openID = id
                } onGroup: { cluster in
                    group = cluster
                }
                .ignoresSafeArea(edges: .bottom)
                VStack {
                    if tracks.isEmpty {
                        Text(language.t("map.empty"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.snow)
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                    SpeedLegend()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle(language.t("map.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $openID) { id in
                if let day = days.first(where: { $0.uuid == id }) {
                    DayDetailView(day: day)
                }
            }
            .sheet(item: $group) { cluster in
                NavigationStack {
                    List(cluster.dayIDs, id: \.self) { id in
                        if let day = days.first(where: { $0.uuid == id }) {
                            Button {
                                group = nil
                                openID = id
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.resort.isEmpty ? language.t("history.resort.empty") : day.resort)
                                        .font(.headline)
                                    Text(FormatFR.dayTitle(day.startedAt, french: language.frenchNumbers, localeID: language.localeIdentifier))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle(language.t("map.cluster", Int32(cluster.dayIDs.count)))
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear { reload() }
            .onChange(of: days.count) { _, _ in reload() }
        }
    }

    private func reload() {
        let relative = UserDefaults.standard.bool(forKey: "slide.speed.relative")
        tracks = days.compactMap { day in
            guard let archive = day.readArchive(), archive.samples.count >= 2 else { return nil }
            let samples = DrawnTrack.simplify(archive.samples)
            guard samples.count >= 2 else { return nil }
            let latitude = samples.reduce(0.0) { $0 + $1.latitude } / Double(samples.count)
            let longitude = samples.reduce(0.0) { $0 + $1.longitude } / Double(samples.count)
            let peak = samples.map(\.speed).max() ?? 0
            return DrawnTrack(
                id: day.uuid,
                samples: samples,
                latitude: latitude,
                longitude: longitude,
                resort: day.resort,
                dayMaxKmh: relative && peak > 1 ? peak * 3.6 : nil
            )
        }
    }
}

enum TrackOwners {
    static var dayIDs: [ObjectIdentifier: UUID] = [:]
}

final class DayPin: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var dayIDs: [UUID]
    init(coordinate: CLLocationCoordinate2D, title: String?, dayIDs: [UUID]) {
        self.coordinate = coordinate
        self.title = title
        self.dayIDs = dayIDs
    }
}

struct WorldTracksMap: UIViewRepresentable {
    var tracks: [DrawnTrack]
    var onOpen: (UUID) -> Void
    var onGroup: (PlaceCluster) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        if #available(iOS 16.0, *) {
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            map.preferredConfiguration = config
        } else {
            map.mapType = .hybrid
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: WorldTracksMap
        private var signature = ""
        private var didFit = false

        init(_ parent: WorldTracksMap) { self.parent = parent }

        func sync(_ map: MKMapView) {
            let ids = parent.tracks.map(\.id.uuidString).joined(separator: ",")
            let far = map.camera.centerCoordinateDistance > 80_000
            let next = ids + (far ? "|far" : "|near")
            if next != signature {
                signature = next
                draw(map, far: far)
            }
            fitOnce(map)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            signature = ""
            sync(mapView)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline, SpeedLineStyle.colors[ObjectIdentifier(line)] != nil {
                return SpeedGradientRenderer(polyline: line)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is DayPin else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "day") ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "day")
            view.annotation = annotation
            let count = (annotation as? DayPin)?.dayIDs.count ?? 1
            let size: CGFloat = count > 1 ? 36 : 26
            let mark = UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
            mark.text = count > 1 ? "\(count)" : "▲"
            mark.textAlignment = .center
            mark.font = .systemFont(ofSize: count > 1 ? 15 : 12, weight: .heavy)
            mark.textColor = UIColor(red: 0.49, green: 0.91, blue: 1, alpha: 1)
            mark.backgroundColor = UIColor(red: 0.03, green: 0.08, blue: 0.14, alpha: 0.9)
            mark.layer.cornerRadius = size / 2
            mark.layer.borderColor = UIColor(red: 0.49, green: 0.91, blue: 1, alpha: 1).cgColor
            mark.layer.borderWidth = 2
            mark.clipsToBounds = true
            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(mark)
            view.frame = mark.frame
            view.centerOffset = CGPoint(x: 0, y: -size / 2)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? DayPin else { return }
            mapView.deselectAnnotation(pin, animated: false)
            open(pin.dayIDs, latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView, map.camera.centerCoordinateDistance <= 80_000 else { return }
            let point = gesture.location(in: map)
            var best: (UUID, CGFloat)?
            for track in parent.tracks {
                let step = max(1, track.samples.count / 80)
                for index in stride(from: 0, to: track.samples.count, by: step) {
                    let sample = track.samples[index]
                    let spot = map.convert(CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude), toPointTo: map)
                    let distance = hypot(spot.x - point.x, spot.y - point.y)
                    if distance < 28, best == nil || distance < best!.1 {
                        best = (track.id, distance)
                    }
                }
            }
            if let best { parent.onOpen(best.0) }
        }

        private func draw(_ map: MKMapView, far: Bool) {
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations)
            if far {
                let points = parent.tracks.map { PlacePoint(id: $0.id, latitude: $0.latitude, longitude: $0.longitude) }
                for cluster in PlaceIndex.clusters(points) {
                    let title = cluster.dayIDs.count == 1 ? parent.tracks.first { $0.id == cluster.dayIDs[0] }?.resort : nil
                    let pin = DayPin(
                        coordinate: CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude),
                        title: title,
                        dayIDs: cluster.dayIDs
                    )
                    map.addAnnotation(pin)
                }
                return
            }
            let region = map.region
            for track in parent.tracks where intersects(track, region) {
                let coords = track.samples.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                let line: MKPolyline = coords.withUnsafeBufferPointer { buffer in
                    MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
                }
                SpeedLineStyle.colors[ObjectIdentifier(line)] = track.samples.map { sample in
                    let rgb = SpeedPaint.rgb(sample.speed, dayMaxKmh: track.dayMaxKmh)
                    return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
                }
                TrackOwners.dayIDs[ObjectIdentifier(line)] = track.id
                map.addOverlay(line)
            }
        }

        private func intersects(_ track: DrawnTrack, _ region: MKCoordinateRegion) -> Bool {
            let padLat = region.span.latitudeDelta
            let padLon = region.span.longitudeDelta
            return abs(track.latitude - region.center.latitude) <= padLat
                && abs(track.longitude - region.center.longitude) <= padLon
        }

        private func fitOnce(_ map: MKMapView) {
            guard !didFit, let first = parent.tracks.first else { return }
            didFit = true
            var minLat = first.latitude, maxLat = first.latitude, minLon = first.longitude, maxLon = first.longitude
            for track in parent.tracks {
                minLat = min(minLat, track.latitude)
                maxLat = max(maxLat, track.latitude)
                minLon = min(minLon, track.longitude)
                maxLon = max(maxLon, track.longitude)
            }
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
            let span = max(maxLat - minLat, maxLon - minLon, 0.02)
            let distance = max(12_000, span * 111_000 * 2.6)
            map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: 0, heading: 0), animated: false)
            signature = ""
            sync(map)
        }

        private func open(_ ids: [UUID], latitude: Double, longitude: Double) {
            if ids.count == 1 {
                parent.onOpen(ids[0])
            } else {
                parent.onGroup(PlaceCluster(id: ids.map(\.uuidString).joined(separator: "-"), latitude: latitude, longitude: longitude, dayIDs: ids))
            }
        }
    }
}

extension DrawnTrack {
    static func simplify(_ samples: [TrackSample]) -> [TrackSample] {
        let smooth = TrackGeometry.smooth(samples)
        guard smooth.count > 180 else { return smooth }
        let step = Int(ceil(Double(smooth.count) / 160.0))
        var picked: [TrackSample] = []
        picked.reserveCapacity(170)
        var index = 0
        while index < smooth.count {
            picked.append(smooth[index])
            index += step
        }
        if let last = smooth.last, picked.last?.id != last.id { picked.append(last) }
        return picked
    }
}
