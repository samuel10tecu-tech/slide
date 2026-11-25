import MapKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingController.self) private var controller
    @Query(sort: \SkiDay.startedAt, order: .reverse) private var days: [SkiDay]
    @Query private var profiles: [RiderProfile]
    @State private var importing = false
    @State private var showImportAlert = false

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }
    private var currentSeason: Season { Season.containing(.now) }

    private var currentDays: [SkiDay] {
        days.filter { currentSeason.contains($0.startedAt) }
    }

    private struct SeasonBucket: Identifiable {
        var season: Season
        var days: [SkiDay]
        var id: String { season.id }
    }

    private var olderSeasons: [SeasonBucket] {
        let groups = Dictionary(grouping: days.filter { !currentSeason.contains($0.startedAt) }) {
            Season.containing($0.startedAt)
        }
        return groups.keys.sorted { $0.start > $1.start }.map { season in
            SeasonBucket(season: season, days: (groups[season] ?? []).sorted { $0.startedAt > $1.startedAt })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SeasonHeader(rollup: SeasonRollup.make(days: days, season: currentSeason), prefs: prefs)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    RecordsRow(rollup: SeasonRollup.make(days: days, season: currentSeason), prefs: prefs)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                daySection(title: "Cette saison", days: currentDays)
                ForEach(olderSeasons) { bucket in
                    daySection(title: bucket.season.title, days: bucket.days)
                }
                if days.isEmpty {
                    empty
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ScreenBackground())
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        importing = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Importer une trace")
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    controller.importURL(url)
                }
            case .failure(let error):
                let cocoa = error as NSError
                if cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError {
                    return
                }
                controller.importData(Data(), filename: "illisible.glisse")
            }
        }
        .onChange(of: controller.importNote) { _, note in
            showImportAlert = note != nil
        }
        .alert("Fichier", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { controller.clearImportNote() }
        } message: {
            Text(controller.importNote ?? "")
        }
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.xml, .json, .plainText, .data]
        if let gpx = UTType(filenameExtension: "gpx") { types.append(gpx) }
        if let session = UTType(filenameExtension: "glisse") { types.append(session) }
        return types
    }

    @ViewBuilder
    private func daySection(title: String, days: [SkiDay]) -> some View {
        if !days.isEmpty {
            Section {
                ForEach(days) { day in
                    NavigationLink {
                        DayDetailView(day: day)
                    } label: {
                        DayRow(day: day, prefs: prefs)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { offsets in
                    delete(offsets, in: days)
                }
            } header: {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Pas encore de journée")
                .font(.title3.weight(.bold))
            Text("Démarre une sortie dans Suivi, ou ajoute la journée d'exemple dans Profil pour voir à quoi ça ressemble.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 12)
    }

    private func delete(_ offsets: IndexSet, in source: [SkiDay]) {
        for index in offsets {
            modelContext.delete(source[index])
        }
        try? modelContext.save()
    }
}

struct SeasonHeader: View {
    var rollup: SeasonRollup
    var prefs: UnitPrefs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rollup.season.title)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            HStack(alignment: .firstTextBaseline) {
                big(FormatFR.altitude(rollup.vertical, prefs: prefs), "dénivelé")
                Spacer()
                big("\(rollup.days)", rollup.days > 1 ? "jours" : "jour")
                Spacer()
                big("\(rollup.runs)", rollup.runs > 1 ? "descentes" : "descente")
            }
            Text(FormatFR.distance(rollup.distance, prefs: prefs) + " parcourus en ski")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func big(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
    }
}

struct RecordsRow: View {
    var rollup: SeasonRollup
    var prefs: UnitPrefs

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                record(
                    "Vitesse",
                    rollup.topSpeed > 0 ? FormatFR.speed(rollup.topSpeed, prefs: prefs) : "—",
                    rollup.topSpeedDate.map { FormatFR.dayShort($0) } ?? "Aucun run",
                    Theme.accent
                )
                record(
                    "Plus longue",
                    rollup.longestRun > 0 ? FormatFR.distance(rollup.longestRun, prefs: prefs) : "—",
                    rollup.longestRunDate.map { FormatFR.dayShort($0) } ?? "Aucune descente",
                    Theme.ice
                )
                record(
                    "Gros jour",
                    rollup.bestDayVertical > 0 ? FormatFR.altitude(rollup.bestDayVertical, prefs: prefs) : "—",
                    rollup.bestDayDate.map { FormatFR.dayShort($0) } ?? "Dénivelé d'une journée",
                    Theme.orange
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private func record(_ title: String, _ value: String, _ detail: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DayRow: View {
    var day: SkiDay
    var prefs: UnitPrefs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(FormatFR.dayTitle(day.startedAt))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if day.isSample {
                    Text("Exemple")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.ice.opacity(0.16), in: Capsule())
                        .foregroundStyle(Theme.ice)
                }
                if !day.isComplete {
                    Text("En cours")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(Theme.orange)
                }
            }
            Text(day.resort.isEmpty ? "Sans station" : day.resort)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline) {
                Text(FormatFR.speed(day.maxSpeed, prefs: prefs))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(day.maxSpeed)))
                Text(FormatFR.speedUnit(prefs))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            Text("\(FormatFR.distance(day.distance, prefs: prefs)) · \(FormatFR.altitude(day.vertical, prefs: prefs)) · \(day.runCount) desc. · \(FormatFR.duration(day.duration))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct DayDetailView: View {
    @Bindable var day: SkiDay
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [RiderProfile]
    @State private var archive: SessionArchive?
    @State private var resortDraft = ""
    @State private var missing = false
    @State private var confirmDelete = false

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }
    private var rider: String {
        let name = profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? day.riderName : name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if day.isSample {
                    Banner(text: "Journée d'exemple, générée dans le téléphone. Tu peux la supprimer.", systemImage: "sparkles", tint: Theme.ice)
                }
                TextField("Nom de la station", text: $resortDraft)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onSubmit { commitResort() }
                if let archive {
                    summary(archive)
                    mapBlock(archive)
                    runsBlock(archive)
                    if !archive.jumps.isEmpty {
                        jumpsBlock(archive)
                    }
                    ShareBar(archive: archive, prefs: prefs, rider: rider)
                        .id(archive.resort)
                    Text("GPX pour les apps de trace, image pour Messages, fichier .glisse pour garder les descentes exactes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else if missing {
                    Banner(text: "Cette journée est illisible. Tu peux la supprimer.", systemImage: "exclamationmark.triangle", tint: Theme.danger)
                }
                Button("Supprimer cette journée", role: .destructive) {
                    confirmDelete = true
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(ScreenBackground())
        .navigationTitle(FormatFR.dayShort(day.startedAt))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resortDraft = day.resort
            if archive == nil {
                archive = day.readArchive()
                missing = archive == nil
            }
        }
        .onChange(of: resortDraft) { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            day.resort = trimmed
            if var current = archive {
                current.resort = trimmed
                archive = current
            }
        }
        .onDisappear {
            commitResort()
        }
        .confirmationDialog("Supprimer cette journée ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                modelContext.delete(day)
                try? modelContext.save()
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func summary(_ archive: SessionArchive) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(label: "Vitesse max", value: FormatFR.speed(archive.maxSpeed, prefs: prefs), systemImage: "flag.checkered")
            StatTile(label: "Distance", value: FormatFR.distance(archive.distance, prefs: prefs), systemImage: "ruler")
            StatTile(label: "Dénivelé", value: FormatFR.altitude(archive.vertical, prefs: prefs), systemImage: "arrow.down")
            StatTile(label: "Durée", value: FormatFR.duration(archive.duration), systemImage: "timer")
        }
    }

    @ViewBuilder
    private func mapBlock(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if archive.samples.count >= 2, let region = TrackGeometry.region(for: archive.samples) {
                TrackMap(samples: archive.samples, region: region)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                Text("Le fond de carte a parfois besoin d'un cache déjà téléchargé. Tes chiffres sont enregistrés même si la carte est vide.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                Banner(text: "Pas assez de points GPS pour dessiner la trace. Les stats restent valables.", systemImage: "map", tint: Theme.muted)
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

    private func runsBlock(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descentes")
                .font(.headline)
            if archive.runs.isEmpty {
                Text("Aucune descente détectée sur cette trace.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            ForEach(archive.runs) { run in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Descente \(run.index)")
                            .font(.subheadline.weight(.bold))
                        Text("\(FormatFR.distance(run.distance, prefs: prefs)) · \(FormatFR.altitude(run.verticalDrop, prefs: prefs)) · \(FormatFR.duration(run.duration))")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                        Text("Moy. \(FormatFR.speed(run.avgSpeed, prefs: prefs)) \(FormatFR.speedUnit(prefs))")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(FormatFR.speed(run.maxSpeed, prefs: prefs))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(run.maxSpeed)))
                        Text("max")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func jumpsBlock(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sauts")
                .font(.headline)
            Text("\(archive.jumpCount) saut\(archive.jumpCount > 1 ? "s" : "") · \(FormatFR.decimal(archive.airtime, fractionDigits: 1)) s d'air")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text("Estimation à partir de l'accéléromètre. Pratique pour comparer, pas une mesure exacte.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func commitResort() {
        let trimmed = resortDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        day.resort = trimmed
        guard var current = archive else {
            try? modelContext.save()
            return
        }
        current.resort = trimmed
        day.write(current)
        archive = current
        try? modelContext.save()
    }
}

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
        let latDelta = max(0.004, (maxLat - minLat) * 1.4)
        let lonDelta = max(0.004, (maxLon - minLon) * 1.4)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private static func coordinate(_ sample: TrackSample) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude)
    }
}

struct TrackMap: View {
    var samples: [TrackSample]
    var region: MKCoordinateRegion
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(TrackGeometry.segments(from: samples)) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(Theme.color(for: segment.band), lineWidth: 5)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onAppear { position = .region(region) }
        .accessibilityLabel("Carte de la trace, colorée selon la vitesse")
    }
}
