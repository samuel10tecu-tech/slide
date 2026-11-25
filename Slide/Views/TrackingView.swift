import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct TrackingView: View {
    @Environment(TrackingController.self) private var controller
    @Environment(LanguageSettings.self) private var language
    @Environment(\.verticalSizeClass) private var verticalSize
    @Query private var profiles: [RiderProfile]
    @State private var confirmStop = false
    @State private var finished: SessionArchive?
    @State private var settingsHint = false
    @State private var follow = true
    @State private var selected: TrackSample?

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }
    private var french: Bool { language.frenchNumbers }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                screen(now: timeline.date)
            }
            .background(ScreenBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog(language.t("tracking.stop.title"), isPresented: $confirmStop, titleVisibility: .visible) {
            Button(language.t("tracking.stop.confirm"), role: .destructive) {
                Haptics.success()
                controller.stop()
            }
            Button(language.t("tracking.stop.continue"), role: .cancel) {}
        } message: {
            Text(language.t("tracking.stop.message"))
        }
        .onChange(of: controller.activity) { old, new in
            if new == .idle, old != .idle, let archive = controller.lastArchive {
                finished = archive
            }
        }
        .onChange(of: controller.summary.qualifiedRuns) { old, new in
            if new > old { Haptics.success() }
        }
        .sheet(item: $finished) { archive in
            SessionSummarySheet(archive: archive, prefs: prefs, rider: riderName, language: language)
        }
        .alert(language.t("tracking.settings.title"), isPresented: $settingsHint) {
            Button(language.t("tracking.settings.open")) { openSettings() }
            Button(language.t("tracking.settings.later"), role: .cancel) {}
        } message: {
            Text(language.t("tracking.settings.message"))
        }
    }

    private var riderName: String {
        profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var homeMountain: String {
        profiles.first?.homeMountain.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func screen(now: Date) -> some View {
        VStack(spacing: 0) {
            if controller.activity != .idle {
                mapBlock
                    .frame(height: verticalSize == .compact ? 180 : 300)
            }
            ScrollView {
                VStack(spacing: 14) {
                    header
                    gauge
                    if let run = controller.summary.openRun, controller.activity == .tracking {
                        openRunStrip(run)
                    }
                    statsGrid(now: now)
                    notices
                    if controller.activity == .idle {
                        intro
                    }
                    if controller.recoverableID != nil && controller.activity == .idle {
                        recoveryCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, controller.activity == .idle ? 12 : 16)
                .padding(.bottom, 8)
            }
            .background(Theme.background)
            controls
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(Theme.background)
        }
    }

    private var mapBlock: some View {
        ZStack(alignment: .bottomLeading) {
            LiveTrackMap(
                samples: controller.mapSamples,
                follow: follow,
                userCoordinate: userCoordinate,
                replay: nil,
                onSelect: nil
            )
            VStack(alignment: .leading, spacing: 8) {
                if let selected {
                    Text("\(FormatFR.speed(selected.speed, prefs: prefs, french: french)) \(FormatFR.speedUnit(prefs))")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                HStack(spacing: 8) {
                    Button {
                        follow.toggle()
                        Haptics.tap()
                    } label: {
                        Label(language.t(follow ? "tracking.follow" : "tracking.recenter"), systemImage: follow ? "location.fill" : "location")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Text(language.t("tracking.map.offline"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }
            .padding(10)
            .foregroundStyle(.white)
        }
    }

    private var userCoordinate: CLLocationCoordinate2D? {
        guard let last = controller.mapSamples.last else { return nil }
        return CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.t("tracking.brand"))
                    .font(.caption.weight(.heavy))
                    .tracking(2.4)
                    .foregroundStyle(Theme.accent)
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            gpsPill
        }
    }

    private var headerTitle: String {
        if controller.isActive {
            return controller.resort.isEmpty ? language.t("tracking.live") : controller.resort
        }
        return homeMountain.isEmpty ? language.t("tracking.ready") : homeMountain
    }

    private var gauge: some View {
        let speed = controller.summary.hasFix ? controller.summary.speed : 0
        let kmh = Units.kmh(fromMps: speed)
        let tint = controller.activity == .tracking && controller.summary.hasFix
            ? Theme.color(for: SpeedBand.forSpeed(speed))
            : Theme.text
        return VStack(spacing: 10) {
            PhaseBadge(
                title: phaseTitle,
                color: phaseColor,
                pulsing: controller.activity == .tracking && controller.summary.phase == .skiing
            )
            SpeedGauge(
                text: FormatFR.speed(speed, prefs: prefs, french: french),
                unit: FormatFR.speedUnit(prefs),
                fraction: min(kmh / 100, 1),
                tint: tint
            )
            .frame(width: 250, height: 250)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RadialGradient(colors: [tint.opacity(0.22), .clear], center: .center, startRadius: 10, endRadius: 180)
        )
    }

    private var phaseTitle: String {
        switch controller.activity {
        case .idle: return language.t("tracking.phase.ready")
        case .paused: return language.t("tracking.phase.pause")
        case .tracking: return language.t(phaseKey(controller.summary.phase))
        }
    }

    private var phaseColor: Color {
        switch controller.activity {
        case .idle: return Theme.muted
        case .paused: return Theme.orange
        case .tracking: return Theme.color(for: controller.summary.phase)
        }
    }

    private func phaseKey(_ phase: TrackPhase) -> String {
        switch phase {
        case .unknown: return "tracking.phase.calibration"
        case .skiing: return "tracking.phase.skiing"
        case .lift: return "tracking.phase.lift"
        case .rest: return "tracking.phase.rest"
        }
    }

    private func statsGrid(now: Date) -> some View {
        let summary = controller.summary
        let duration = controller.isActive ? controller.duration(at: now) : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(label: language.t("tracking.stat.max"), value: FormatFR.speed(summary.maxSpeed, prefs: prefs, french: french), systemImage: "flag.checkered")
            StatTile(label: language.t("tracking.stat.distance"), value: FormatFR.distance(summary.distance, prefs: prefs, french: french), systemImage: "ruler")
            StatTile(label: language.t("tracking.stat.vertical"), value: FormatFR.altitude(summary.vertical, prefs: prefs, french: french), systemImage: "arrow.down")
            StatTile(label: language.t("tracking.stat.altitude"), value: summary.hasFix ? FormatFR.altitude(summary.altitude, prefs: prefs, french: french) : "—", systemImage: "mountain.2.fill")
            StatTile(label: language.t("tracking.stat.duration"), value: FormatFR.duration(duration), systemImage: "timer")
            StatTile(label: language.t("tracking.stat.runs"), value: "\(summary.qualifiedRuns)", systemImage: "figure.skiing.downhill")
        }
    }

    private func openRunStrip(_ run: RunRecord) -> some View {
        let title = controller.summary.qualifiedRuns == run.index
            ? language.t("tracking.run.named", Int32(run.index))
            : language.t("tracking.run.current")
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text("\(FormatFR.distance(run.distance, prefs: prefs, french: french)) · \(FormatFR.altitude(run.verticalDrop, prefs: prefs, french: french)) · max \(FormatFR.speed(run.maxSpeed, prefs: prefs, french: french))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var notices: some View {
        if controller.lowPower && controller.isActive {
            Banner(text: language.t("tracking.banner.lowpower"), systemImage: "battery.25percent", tint: Theme.orange)
        }
        if controller.activity == .tracking, let fix = controller.lastFixAt, Date().timeIntervalSince(fix) > 8 {
            Banner(text: language.t("tracking.banner.stale"), systemImage: "location.slash", tint: Theme.orange)
        } else if controller.activity == .tracking, controller.summary.accuracy > 25 {
            Banner(text: language.t("tracking.banner.accuracy", Int32(controller.summary.accuracy)), systemImage: "location", tint: Theme.ice)
        }
        if let notice = controller.notice, controller.activity == .idle {
            switch notice {
            case .locationBlocked, .locationDenied:
                Banner(text: notice.message(language), systemImage: "location.slash.fill", tint: Theme.danger)
            default:
                EmptyView()
            }
        }
        if controller.activity == .tracking && controller.auth == .authorizedWhenInUse {
            Banner(text: language.t("tracking.banner.wheninuse"), systemImage: "lock.open", tint: Theme.ice)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("tracking.intro"))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(language.t(controller.usingBarometer ? "tracking.baro.on" : "tracking.baro.off"))
                .font(.footnote)
                .foregroundStyle(Theme.muted.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.t("tracking.recovery.title")).font(.headline)
            Text(controller.recoverableTitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                Button(language.t("tracking.resume")) { controller.resumeRecovered() }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.black)
                    .buttonStyle(.plain)
                Button(language.t("tracking.recovery.close")) { controller.closeRecovered() }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var controls: some View {
        switch controller.activity {
        case .idle:
            BigButton(title: language.t("tracking.start"), systemImage: "play.fill", fill: Theme.accent) {
                Haptics.tap()
                if controller.auth == .denied || controller.auth == .restricted {
                    settingsHint = true
                } else {
                    controller.requestPermissionThenStart(resort: homeMountain, rider: riderName)
                }
            }
        case .tracking:
            HStack(spacing: 10) {
                BigButton(title: language.t("tracking.pause"), systemImage: "pause.fill", fill: Theme.surface2, foreground: Theme.text) {
                    Haptics.tap()
                    controller.pause()
                }
                BigButton(title: language.t("tracking.stop"), systemImage: "stop.fill", fill: Theme.danger, foreground: .white) {
                    confirmStop = true
                }
            }
        case .paused:
            HStack(spacing: 10) {
                BigButton(title: language.t("tracking.resume"), systemImage: "play.fill", fill: Theme.accent) {
                    Haptics.tap()
                    controller.resume()
                }
                BigButton(title: language.t("tracking.stop"), systemImage: "stop.fill", fill: Theme.danger, foreground: .white) {
                    confirmStop = true
                }
            }
        }
    }

    private var gpsPill: some View {
        let accuracy = controller.summary.accuracy
        let title: String
        let color: Color
        if controller.activity != .tracking {
            title = language.t("tracking.gps")
            color = Theme.muted
        } else if !controller.summary.hasFix || accuracy < 0 {
            title = language.t("tracking.gps.search")
            color = Theme.orange
        } else if accuracy <= 8 {
            title = language.t("tracking.gps.good")
            color = Theme.accent
        } else if accuracy <= 20 {
            title = language.t("tracking.gps.ok")
            color = Theme.ice
        } else {
            title = language.t("tracking.gps.weak")
            color = Theme.orange
        }
        return Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
