import SwiftUI
import UIKit

struct StatsCardView: View {
    var archive: SessionArchive
    var prefs: UnitPrefs
    var rider: String
    var language: LanguageSettings

    private var french: Bool { language.frenchNumbers }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(language.t("tracking.brand"))
                    .font(.caption.weight(.heavy))
                    .tracking(2.2)
                Spacer()
                Text(FormatFR.dayShort(archive.startedAt, french: french))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(archive.resort.isEmpty ? language.t("summary.saved") : archive.resort)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
                if !rider.isEmpty {
                    Text(rider)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(FormatFR.speed(archive.maxSpeed, prefs: prefs, french: french))
                    .font(.system(size: 78, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(archive.maxSpeed)))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("\(FormatFR.speedUnit(prefs)) \(language.t("history.max"))")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 8) {
                cardStat(language.t("tracking.stat.distance"), FormatFR.distance(archive.distance, prefs: prefs, french: french))
                cardStat(language.t("tracking.stat.vertical"), FormatFR.altitude(archive.vertical, prefs: prefs, french: french))
            }
            HStack(spacing: 8) {
                cardStat(language.t("tracking.stat.runs"), "\(archive.runs.count)")
                cardStat(language.t("tracking.stat.duration"), FormatFR.duration(archive.duration))
            }

            TrackSketch(samples: archive.samples)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Text(language.t("card.offline"))
                Spacer()
                if archive.jumpCount > 0 {
                    Text(language.t("card.air", FormatFR.decimal(archive.airtime, fractionDigits: 1, french: french)))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.muted)
        }
        .padding(22)
        .frame(width: 360, height: 640, alignment: .top)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Theme.accent.frame(height: 6)
        }
    }

    private func cardStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TrackSketch: View {
    var samples: [TrackSample]

    var body: some View {
        Canvas { context, size in
            guard samples.count >= 2 else {
                let dot = Path(ellipseIn: CGRect(x: size.width / 2 - 5, y: size.height / 2 - 5, width: 10, height: 10))
                context.fill(dot, with: .color(Theme.accent))
                return
            }
            let lats = samples.map(\.latitude)
            let lons = samples.map(\.longitude)
            let minLat = lats.min() ?? 0
            let maxLat = lats.max() ?? 0
            let minLon = lons.min() ?? 0
            let maxLon = lons.max() ?? 0
            let pad = 16.0
            let xSpan = max(maxLon - minLon, 0.00008)
            let ySpan = max(maxLat - minLat, 0.00008)
            func point(_ sample: TrackSample) -> CGPoint {
                let x = pad + (sample.longitude - minLon) / xSpan * (size.width - pad * 2)
                let y = pad + (maxLat - sample.latitude) / ySpan * (size.height - pad * 2)
                return CGPoint(x: x, y: y)
            }
            for index in 1..<samples.count {
                var path = Path()
                path.move(to: point(samples[index - 1]))
                path.addLine(to: point(samples[index]))
                let band = SpeedBand.forSpeed(samples[index].speed)
                context.stroke(path, with: .color(Theme.color(for: band)), lineWidth: 3.5)
            }
        }
        .padding(8)
        .accessibilityLabel("Tracé de la sortie")
    }
}

enum ShareExport {
    @MainActor
    static func files(for archive: SessionArchive, prefs: UnitPrefs, rider: String, language: LanguageSettings) -> (gpx: URL?, image: URL?, session: URL?) {
        let stamp = FormatFR.fileStamp(archive.startedAt)
        let folder = FileManager.default.temporaryDirectory
        let gpxURL = folder.appendingPathComponent("Slide-\(stamp).gpx")
        let sessionURL = folder.appendingPathComponent("Slide-\(stamp).slide")
        let imageURL = folder.appendingPathComponent("Slide-\(stamp).png")
        let gpx = GPXCodec.encode(archive: archive)
        try? gpx.data(using: .utf8)?.write(to: gpxURL, options: .atomic)
        if let data = try? SessionFile.encode(archive) {
            try? data.write(to: sessionURL, options: .atomic)
        }
        var image: URL?
        let renderer = ImageRenderer(content: StatsCardView(archive: archive, prefs: prefs, rider: rider, language: language).environment(\.colorScheme, .dark))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        if let uiImage = renderer.uiImage, let png = uiImage.pngData() {
            try? png.write(to: imageURL, options: .atomic)
            image = imageURL
        }
        return (gpxURL, image, sessionURL)
    }
}

struct ShareBar: View {
    var archive: SessionArchive
    var prefs: UnitPrefs
    var rider: String
    var language: LanguageSettings
    @State private var gpx: URL?
    @State private var image: URL?
    @State private var session: URL?

    var body: some View {
        HStack(spacing: 8) {
            link(gpx, language.t("share.gpx"), "map")
            link(image, language.t("share.image"), "photo")
            link(session, language.t("share.file"), "doc")
        }
        .task { prepare() }
    }

    @ViewBuilder
    private func link(_ url: URL?, _ title: String, _ symbol: String) -> some View {
        if let url {
            ShareLink(item: url, preview: SharePreview(title, image: Image(systemName: symbol))) {
                VStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.headline)
                    Text(title)
                        .font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Theme.text)
            }
        }
    }

    @MainActor
    private func prepare() {
        let made = ShareExport.files(for: archive, prefs: prefs, rider: rider, language: language)
        gpx = made.gpx
        image = made.image
        session = made.session
    }
}

struct SessionSummarySheet: View {
    var archive: SessionArchive
    var prefs: UnitPrefs
    var rider: String
    var language: LanguageSettings
    @Environment(\.dismiss) private var dismiss

    private var french: Bool { language.frenchNumbers }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(archive.resort.isEmpty ? language.t("summary.saved") : archive.resort)
                        .font(.title2.weight(.bold))
                    SpeedGauge(
                        text: FormatFR.speed(archive.maxSpeed, prefs: prefs, french: french),
                        unit: FormatFR.speedUnit(prefs),
                        fraction: min(Units.kmh(fromMps: archive.maxSpeed) / 100, 1),
                        tint: Theme.color(for: SpeedBand.forSpeed(archive.maxSpeed))
                    )
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatTile(label: language.t("tracking.stat.distance"), value: FormatFR.distance(archive.distance, prefs: prefs, french: french), systemImage: "ruler")
                        StatTile(label: language.t("tracking.stat.vertical"), value: FormatFR.altitude(archive.vertical, prefs: prefs, french: french), systemImage: "arrow.down")
                        StatTile(label: language.t("tracking.stat.runs"), value: "\(archive.runs.count)", systemImage: "figure.skiing.downhill")
                        StatTile(label: language.t("tracking.stat.duration"), value: FormatFR.duration(archive.duration), systemImage: "timer")
                    }
                    if archive.samples.count > 2 {
                        SpeedAltitudeChart(
                            samples: archive.samples,
                            prefs: prefs,
                            speedTitle: language.t("history.chart.speed"),
                            altitudeTitle: language.t("history.chart.altitude")
                        )
                    }
                    RunBarChart(runs: archive.runs, prefs: prefs, title: language.t("history.chart.runs"))
                    Text(language.t("summary.share"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    ShareBar(archive: archive, prefs: prefs, rider: rider, language: language)
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle(language.t("summary.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.t("summary.ok")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}
