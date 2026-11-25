import CoreLocation
import SwiftUI
import UIKit

struct TrackingView: View {
    @Environment(TrackingController.self) private var controller
    @Environment(\.verticalSizeClass) private var verticalSize
    @Query private var profiles: [RiderProfile]
    @State private var confirmStop = false
    @State private var finished: SessionArchive?
    @State private var settingsHint = false

    private var prefs: UnitPrefs { profiles.first?.prefs ?? .metric }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                screen(now: timeline.date)
            }
            .background(ScreenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog("Terminer la sortie ?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Terminer et enregistrer", role: .destructive) {
                controller.stop()
            }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("La journée reste dans l'historique, sur ce téléphone.")
        }
        .onChange(of: controller.activity) { old, new in
            if new == .idle, old != .idle, let archive = controller.lastArchive {
                finished = archive
            }
        }
        .sheet(item: $finished) { archive in
            SessionSummarySheet(archive: archive, prefs: prefs, rider: riderName)
        }
        .alert("Position", isPresented: $settingsHint) {
            Button("Ouvrir Réglages") { openSettings() }
            Button("Plus tard", role: .cancel) {}
        } message: {
            Text("Choisis « Toujours » pour que le suivi continue dans la poche, écran verrouillé. Glisse coupe le GPS quand tu termines.")
        }
        .sensoryFeedback(.impact, trigger: controller.activity)
        .sensoryFeedback(.success, trigger: controller.summary.qualifiedRuns)
    }

    private var riderName: String {
        profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var homeMountain: String {
        profiles.first?.homeMountain.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func screen(now: Date) -> some View {
        VStack(spacing: 0) {
            if verticalSize == .compact {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 8) {
                        header
                        badge
                        speedBlock
                    }
                    .frame(maxWidth: .infinity)
                    ScrollView { sideContent(now: now) }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        badge
                        speedBlock
                        sideContent(now: now)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            controls
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GLISSE")
                    .font(.caption.weight(.heavy))
                    .tracking(2.4)
                    .foregroundStyle(Theme.accent)
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            gpsPill
        }
    }

    private var headerTitle: String {
        if controller.isActive {
            return controller.resort.isEmpty ? "Sortie en cours" : controller.resort
        }
        return homeMountain.isEmpty ? "Prêt à tracer" : homeMountain
    }

    private var phaseTitle: String {
        switch controller.activity {
        case .idle: return "Prêt"
        case .paused: return "Pause"
        case .tracking: return PhaseCopy.title(controller.summary.phase, active: true)
        }
    }

    private var phaseColor: Color {
        switch controller.activity {
        case .idle: return Theme.muted
        case .paused: return Theme.orange
        case .tracking: return Theme.color(for: controller.summary.phase)
        }
    }

    private var badge: some View {
        PhaseBadge(
            title: phaseTitle,
            color: phaseColor,
            pulsing: controller.activity == .tracking && controller.summary.phase == .skiing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var speedBlock: some View {
        let speed = controller.summary.hasFix ? controller.summary.speed : 0
        let color = controller.activity == .tracking && controller.summary.hasFix
            ? Theme.color(for: SpeedBand.forSpeed(speed))
            : Theme.text
        return VStack(alignment: .leading, spacing: 0) {
            Text(FormatFR.speed(speed, prefs: prefs))
                .font(.system(size: verticalSize == .compact ? 76 : 104, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .animation(.snappy, value: FormatFR.speed(speed, prefs: prefs))
            Text(FormatFR.speedUnit(prefs))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .background(alignment: .leading) {
            Circle()
                .fill(color.opacity(controller.activity == .tracking ? 0.16 : 0))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -40, y: 10)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vitesse \(FormatFR.speed(speed, prefs: prefs)) \(FormatFR.speedUnit(prefs))")
    }

    private func sideContent(now: Date) -> some View {
        VStack(spacing: 12) {
            statsGrid(now: now)
            if let run = controller.summary.openRun, controller.activity == .tracking {
                openRunStrip(run)
            }
            notices
            if controller.activity == .idle {
                intro
            }
            if controller.recoverableID != nil && controller.activity == .idle {
                recoveryCard
            }
        }
    }

    private func statsGrid(now: Date) -> some View {
        let summary = controller.summary
        let duration = controller.isActive ? controller.duration(at: now) : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(label: "Vitesse max", value: FormatFR.speed(summary.maxSpeed, prefs: prefs), systemImage: "flag.checkered")
            StatTile(label: "Distance", value: FormatFR.distance(summary.distance, prefs: prefs), systemImage: "ruler")
            StatTile(label: "Dénivelé", value: FormatFR.altitude(summary.vertical, prefs: prefs), systemImage: "arrow.down")
            StatTile(label: "Altitude", value: summary.hasFix ? FormatFR.altitude(summary.altitude, prefs: prefs) : "—", systemImage: "mountain.2.fill")
            StatTile(label: "Durée", value: FormatFR.duration(duration), systemImage: "timer")
            StatTile(label: "Descentes", value: "\(summary.qualifiedRuns)", systemImage: "figure.skiing.downhill")
        }
    }

    private func openRunStrip(_ run: RunRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.summary.qualifiedRuns == run.index ? "Descente \(run.index)" : "Descente en cours")
                    .font(.subheadline.weight(.bold))
                Text("\(FormatFR.distance(run.distance, prefs: prefs)) · \(FormatFR.altitude(run.verticalDrop, prefs: prefs)) · max \(FormatFR.speed(run.maxSpeed, prefs: prefs))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var notices: some View {
        if controller.lowPower && controller.isActive {
            Banner(
                text: "Le mode économie d'énergie peut couper le GPS. Désactive-le pour une journée complète.",
                systemImage: "battery.25percent",
                tint: Theme.orange
            )
        }
        if controller.activity == .tracking, let fix = controller.lastFixAt, Date().timeIntervalSince(fix) > 8 {
            Banner(
                text: "Le GPS ne répond plus. Sors le téléphone de la poche intérieure une seconde, ou attends le ciel ouvert.",
                systemImage: "location.slash",
                tint: Theme.orange
            )
        } else if controller.activity == .tracking, controller.summary.accuracy > 25 {
            Banner(
                text: "GPS faible (\(Int(controller.summary.accuracy)) m). Les points trop imprécis sont ignorés.",
                systemImage: "location",
                tint: Theme.ice
            )
        }
        if let error = controller.locationError, controller.activity == .idle {
            Banner(text: error, systemImage: "location.slash.fill", tint: Theme.danger)
        }
        if controller.activity == .tracking && controller.auth == .authorizedWhenInUse {
            Banner(
                text: "Pour le suivi écran verrouillé, passe la position sur « Toujours » dans Réglages.",
                systemImage: "lock.open",
                tint: Theme.ice
            )
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Démarre en bas de la remontée. Glisse sépare les descentes, les remontées et les pauses. Le téléphone peut rester dans la poche.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(controller.usingBarometer
                 ? "Altitude au baromètre."
                 : "L'altitude utilise le baromètre du téléphone quand il est là, sinon le GPS.")
                .font(.footnote)
                .foregroundStyle(Theme.muted.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sortie pas terminée")
                .font(.headline)
            Text(controller.recoverableTitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                Button("Reprendre") { controller.resumeRecovered() }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.black)
                    .buttonStyle(.plain)
                Button("Clôturer") { controller.closeRecovered() }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule())
                    .foregroundStyle(Theme.text)
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
            BigButton(title: "Démarrer", systemImage: "play.fill", fill: Theme.accent) {
                if controller.auth == .denied || controller.auth == .restricted {
                    settingsHint = true
                } else {
                    controller.requestPermissionThenStart(resort: homeMountain, rider: riderName)
                }
            }
        case .tracking:
            HStack(spacing: 10) {
                BigButton(title: "Pause", systemImage: "pause.fill", fill: Theme.surface2, foreground: Theme.text) {
                    controller.pause()
                }
                BigButton(title: "Stop", systemImage: "stop.fill", fill: Theme.danger, foreground: .white) {
                    confirmStop = true
                }
            }
        case .paused:
            HStack(spacing: 10) {
                BigButton(title: "Reprendre", systemImage: "play.fill", fill: Theme.accent) {
                    controller.resume()
                }
                BigButton(title: "Stop", systemImage: "stop.fill", fill: Theme.danger, foreground: .white) {
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
            title = "GPS"
            color = Theme.muted
        } else if !controller.summary.hasFix || accuracy < 0 {
            title = "GPS…"
            color = Theme.orange
        } else if accuracy <= 8 {
            title = "GPS net"
            color = Theme.accent
        } else if accuracy <= 20 {
            title = "GPS ok"
            color = Theme.ice
        } else {
            title = "GPS faible"
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
