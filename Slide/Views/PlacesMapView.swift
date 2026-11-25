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

struct PlacesMapView: View {
    @Environment(LanguageSettings.self) private var language
    @Query(sort: \SkiDay.startedAt, order: .reverse) private var days: [SkiDay]
    @State private var openID: UUID?
    @State private var group: PlaceCluster?
    @State private var position: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 46.2, longitude: 7.4), distance: 1_800_000, heading: 0, pitch: 0)
    )

    private var points: [PlacePoint] {
        days.compactMap { day in
            guard let archive = day.readArchive(), !archive.samples.isEmpty else { return nil }
            let lat = archive.samples.reduce(0.0) { $0 + $1.latitude } / Double(archive.samples.count)
            let lon = archive.samples.reduce(0.0) { $0 + $1.longitude } / Double(archive.samples.count)
            return PlacePoint(id: day.uuid, latitude: lat, longitude: lon)
        }
    }

    private var clusters: [PlaceCluster] { PlaceIndex.clusters(points) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Map(position: $position) {
                    ForEach(clusters) { cluster in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude)) {
                            Button {
                                if cluster.dayIDs.count == 1 {
                                    openID = cluster.dayIDs[0]
                                } else {
                                    group = cluster
                                }
                                Haptics.tap()
                            } label: {
                                pin(cluster)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                if points.isEmpty {
                    Text(language.t("map.empty"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.snow)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(16)
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
            .onAppear { fit() }
        }
    }

    private func pin(_ cluster: PlaceCluster) -> some View {
        ZStack {
            Circle()
                .fill(Theme.ink.opacity(0.88))
                .frame(width: cluster.dayIDs.count > 1 ? 40 : 28, height: cluster.dayIDs.count > 1 ? 40 : 28)
            Circle()
                .stroke(Theme.accent, lineWidth: 2)
                .frame(width: cluster.dayIDs.count > 1 ? 40 : 28, height: cluster.dayIDs.count > 1 ? 40 : 28)
            if cluster.dayIDs.count > 1 {
                Text("\(cluster.dayIDs.count)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.snow)
            } else {
                Image(systemName: "mountain.2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func fit() {
        guard let first = points.first else { return }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = max(maxLat - minLat, maxLon - minLon)
        let distance = max(8_000, span * 111_000 * 2.4)
        position = .camera(MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 20))
    }
}
