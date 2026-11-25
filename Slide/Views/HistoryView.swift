import Combine
import MapKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingController.self) private var controller
    @Environment(LanguageSettings.self) private var language
    @Query(sort: \SkiDay.startedAt, order: .reverse) private var days: [SkiDay]
    @Query private var profiles: [RiderProfile]
    @State private var importing = false
    @State private var showImportAlert = false

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }
    private var french: Bool { language.frenchNumbers }
    private var currentSeason: Season { Season.containing(.now) }
    private var currentDays: [SkiDay] { days.filter { currentSeason.contains($0.startedAt) } }

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
                    SeasonHeader(rollup: SeasonRollup.make(days: days, season: currentSeason), prefs: prefs, language: language)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    RecordsRow(rollup: SeasonRollup.make(days: days, season: currentSeason), prefs: prefs, language: language)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                daySection(title: language.t("history.section.now"), days: currentDays)
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
            .navigationTitle(language.t("history.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { importing = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel(language.t("history.import"))
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { controller.importURL(url) }
            case .failure(let error):
                let cocoa = error as NSError
                if cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError { return }
                controller.importData(Data(), filename: "bad.slide")
            }
        }
        .onChange(of: controller.notice) { _, note in
            switch note {
            case .gpxImported, .sessionImported, .fileUnknown, .fileUnreadable, .memoryNotReady:
                showImportAlert = true
            default:
                break
            }
        }
        .alert(language.t("history.file.title"), isPresented: $showImportAlert) {
            Button(language.t("history.file.ok"), role: .cancel) { controller.clearNotice() }
        } message: {
            Text(controller.notice?.message(language) ?? "")
        }
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.xml, .json, .plainText, .data]
        if let gpx = UTType(filenameExtension: "gpx") { types.append(gpx) }
        if let session = UTType(filenameExtension: "slide") { types.append(session) }
        if let legacy = UTType(filenameExtension: "glisse") { types.append(legacy) }
        return types
    }

    @ViewBuilder
    private func daySection(title: String, days: [SkiDay]) -> some View {
        if !days.isEmpty {
            Section {
                ForEach(days) { day in
                    NavigationLink { DayDetailView(day: day) } label: {
                        DayRow(day: day, prefs: prefs, language: language)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { delete($0, in: days) }
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
            Text(language.t("history.empty.title")).font(.title3.weight(.bold))
            Text(language.t("history.empty.body"))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func delete(_ offsets: IndexSet, in source: [SkiDay]) {
        for index in offsets { modelContext.delete(source[index]) }
        try? modelContext.save()
    }
}

struct SeasonHeader: View {
    var rollup: SeasonRollup
    var prefs: UnitPrefs
    var language: LanguageSettings

    var body: some View {
        let french = language.frenchNumbers
        VStack(alignment: .leading, spacing: 12) {
            Text(rollup.season.title).font(.headline).foregroundStyle(Theme.accent)
            HStack(alignment: .firstTextBaseline) {
                big(FormatFR.altitude(rollup.vertical, prefs: prefs, french: french), language.t("tracking.stat.vertical"))
                Spacer()
                big("\(rollup.days)", rollup.days > 1 ? language.t("history.season.days") : language.t("history.season.day"))
                Spacer()
                big("\(rollup.runs)", rollup.runs > 1 ? language.t("history.season.runs") : language.t("history.season.run"))
            }
            Text(FormatFR.distance(rollup.distance, prefs: prefs, french: french) + " " + language.t("history.season.distance"))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func big(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
        }
    }
}

struct RecordsRow: View {
    var rollup: SeasonRollup
    var prefs: UnitPrefs
    var language: LanguageSettings

    var body: some View {
        let french = language.frenchNumbers
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                record(language.t("history.record.speed"), rollup.topSpeed > 0 ? FormatFR.speed(rollup.topSpeed, prefs: prefs, french: french) : "—", rollup.topSpeedDate.map { FormatFR.dayShort($0, french: french, localeID: language.localeIdentifier) } ?? language.t("history.record.none.speed"), Theme.accent)
                record(language.t("history.record.longest"), rollup.longestRun > 0 ? FormatFR.distance(rollup.longestRun, prefs: prefs, french: french) : "—", rollup.longestRunDate.map { FormatFR.dayShort($0, french: french, localeID: language.localeIdentifier) } ?? language.t("history.record.none.long"), Theme.ice)
                record(language.t("history.record.day"), rollup.bestDayVertical > 0 ? FormatFR.altitude(rollup.bestDayVertical, prefs: prefs, french: french) : "—", rollup.bestDayDate.map { FormatFR.dayShort($0, french: french, localeID: language.localeIdentifier) } ?? language.t("history.record.none.vert"), Theme.orange)
            }
            .padding(.horizontal, 16)
        }
    }

    private func record(_ title: String, _ value: String, _ detail: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(tint)
            Text(value).font(.title2.weight(.bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(detail).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DayRow: View {
    var day: SkiDay
    var prefs: UnitPrefs
    var language: LanguageSettings

    var body: some View {
        let french = language.frenchNumbers
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(FormatFR.dayTitle(day.startedAt, french: french, localeID: language.localeIdentifier)).font(.subheadline.weight(.semibold))
                Spacer()
                if day.isSample { pill(language.t("history.example"), Theme.ice) }
                if !day.isComplete { pill(language.t("history.open"), Theme.orange) }
            }
            Text(day.resort.isEmpty ? language.t("history.resort.empty") : day.resort)
                .font(.caption).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline) {
                Text(FormatFR.speed(day.maxSpeed, prefs: prefs, french: french))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(day.maxSpeed)))
                Text(FormatFR.speedUnit(prefs)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                Spacer()
            }
            Text("\(FormatFR.distance(day.distance, prefs: prefs, french: french)) · \(FormatFR.altitude(day.vertical, prefs: prefs, french: french)) · \(day.runCount) · \(FormatFR.duration(day.duration))")
                .font(.footnote.monospacedDigit()).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

struct DayDetailView: View {
    @Bindable var day: SkiDay
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageSettings.self) private var language
    @Query private var profiles: [RiderProfile]
    @State private var archive: SessionArchive?
    @State private var resortDraft = ""
    @State private var missing = false
    @State private var confirmDelete = false
    @State private var picked: TrackSample?
    @State private var playing = false
    @State private var replayIndex = 0

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }
    private var french: Bool { language.frenchNumbers }
    private var rider: String {
        let name = profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? day.riderName : name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if day.isSample {
                    Banner(text: language.t("history.sample.banner"), systemImage: "sparkles", tint: Theme.ice)
                }
                TextField(language.t("history.resort.placeholder"), text: $resortDraft)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onSubmit { commitResort() }
                if let archive {
                    summary(archive)
                    mapBlock(archive)
                    if archive.samples.count > 2 {
                        replayControls(archive)
                        SpeedAltitudeChart(
                            samples: archive.samples,
                            prefs: prefs,
                            speedTitle: language.t("history.chart.speed"),
                            altitudeTitle: language.t("history.chart.altitude")
                        )
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    RunBarChart(runs: archive.runs, prefs: prefs, title: language.t("history.chart.runs"))
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    runsBlock(archive)
                    if !archive.jumps.isEmpty { jumpsBlock(archive) }
                    ShareBar(archive: archive, prefs: prefs, rider: rider, language: language)
                        .id(archive.resort)
                    Text(language.t("history.share.hint"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else if missing {
                    Banner(text: language.t("history.broken"), systemImage: "exclamationmark.triangle", tint: Theme.danger)
                }
                Button(language.t("history.delete"), role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(ScreenBackground())
        .navigationTitle(FormatFR.dayShort(day.startedAt, french: french, localeID: language.localeIdentifier))
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
        .onDisappear { commitResort() }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            guard playing, let count = archive?.samples.count, count > 1 else { return }
            replayIndex = (replayIndex + max(1, count / 700)) % count
        }
        .confirmationDialog(language.t("history.delete.title"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(language.t("history.delete.confirm"), role: .destructive) {
                modelContext.delete(day)
                try? modelContext.save()
                dismiss()
            }
            Button(language.t("history.cancel"), role: .cancel) {}
        }
    }

    private func summary(_ archive: SessionArchive) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(label: language.t("tracking.stat.max"), value: FormatFR.speed(archive.maxSpeed, prefs: prefs, french: french), systemImage: "flag.checkered")
            StatTile(label: language.t("tracking.stat.distance"), value: FormatFR.distance(archive.distance, prefs: prefs, french: french), systemImage: "ruler")
            StatTile(label: language.t("tracking.stat.vertical"), value: FormatFR.altitude(archive.vertical, prefs: prefs, french: french), systemImage: "arrow.down")
            StatTile(label: language.t("tracking.stat.duration"), value: FormatFR.duration(archive.duration), systemImage: "timer")
        }
    }

    @ViewBuilder
    private func mapBlock(_ archive: SessionArchive) -> some View {
        if archive.samples.count >= 2, TrackGeometry.region(for: archive.samples) != nil {
            VStack(alignment: .leading, spacing: 8) {
                LiveTrackMap(
                    samples: archive.samples,
                    follow: false,
                    userCoordinate: nil,
                    replay: playing || replayIndex > 0 ? TrackGeometry.coordinate(archive.samples[min(replayIndex, archive.samples.count - 1)]) : nil,
                    onSelect: { picked = $0 }
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                SpeedLegend()
                if let picked {
                    Text("\(language.t("history.point.speed")) · \(FormatFR.speed(picked.speed, prefs: prefs, french: french)) \(FormatFR.speedUnit(prefs)) · \(FormatFR.altitude(picked.rawAltitude, prefs: prefs, french: french)) · \(FormatFR.clock(picked.time))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Text(language.t("history.map.note"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        } else {
            Banner(text: language.t("history.map.empty"), systemImage: "map", tint: Theme.muted)
        }
    }

    private func replayControls(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language.t("history.replay")).font(.headline)
                Spacer()
                Button(language.t(playing ? "history.replay.pause" : "history.replay.play")) {
                    playing.toggle()
                    Haptics.tap()
                }
                .font(.subheadline.weight(.bold))
            }
            Slider(
                value: Binding(
                    get: { Double(replayIndex) },
                    set: { replayIndex = Int($0) }
                ),
                in: 0...Double(max(archive.samples.count - 1, 1))
            )
            .tint(Theme.accent)
            let sample = archive.samples[min(replayIndex, archive.samples.count - 1)]
            Text("\(FormatFR.speed(sample.speed, prefs: prefs, french: french)) \(FormatFR.speedUnit(prefs)) · \(FormatFR.altitude(sample.rawAltitude, prefs: prefs, french: french))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
    }

    private func runsBlock(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("history.runs")).font(.headline)
            if archive.runs.isEmpty {
                Text(language.t("history.runs.empty")).font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(archive.runs) { run in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.t("history.run", Int32(run.index))).font(.subheadline.weight(.bold))
                        Text("\(FormatFR.distance(run.distance, prefs: prefs, french: french)) · \(FormatFR.altitude(run.verticalDrop, prefs: prefs, french: french)) · \(FormatFR.duration(run.duration))")
                            .font(.footnote.monospacedDigit()).foregroundStyle(Theme.muted)
                        Text(language.t("history.avg", FormatFR.speed(run.avgSpeed, prefs: prefs, french: french), FormatFR.speedUnit(prefs)))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(FormatFR.speed(run.maxSpeed, prefs: prefs, french: french))
                            .font(.title3.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Theme.color(for: SpeedBand.forSpeed(run.maxSpeed)))
                        Text(language.t("history.max")).font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func jumpsBlock(_ archive: SessionArchive) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(language.t("history.jumps")).font(.headline)
            Text(language.t("history.jumps.line", Int32(archive.jumpCount), FormatFR.decimal(archive.airtime, fractionDigits: 1, french: french)))
                .font(.title3.weight(.bold)).monospacedDigit()
            Text(language.t("history.jumps.note")).font(.footnote).foregroundStyle(Theme.muted)
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
