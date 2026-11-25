import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingController.self) private var controller
    @Environment(LanguageSettings.self) private var language
    @Query private var profiles: [RiderProfile]
    @State private var confirmErase = false
    @State private var note: AppNotice?

    private var profile: RiderProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    languageBlock
                    if let profile { editor(profile) }
                    about
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle(language.t("profile.title"))
            .onAppear { _ = DayStore.profile(in: modelContext) }
        }
        .alert(language.t("profile.title"), isPresented: Binding(
            get: { note != nil },
            set: { if !$0 { note = nil } }
        )) {
            Button(language.t("summary.ok"), role: .cancel) { note = nil }
        } message: {
            Text(note?.message(language) ?? "")
        }
        .confirmationDialog(language.t("profile.erase.title"), isPresented: $confirmErase, titleVisibility: .visible) {
            Button(language.t("profile.erase.confirm"), role: .destructive) {
                controller.eraseAllDaysAndTricks()
            }
            Button(language.t("history.cancel"), role: .cancel) {}
        } message: {
            Text(language.t("profile.erase.message"))
        }
    }

    private var languageBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("profile.language"))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
            Picker(language.t("profile.language"), selection: Bindable(language).choice) {
                Text(language.t("profile.language.system")).tag(AppLanguage.system)
                ForEach(AppLanguage.allCases.filter { $0 != .system }) { item in
                    Text(item.endonym).tag(item)
                }
            }
            .pickerStyle(.menu)
            Text(language.t("profile.language.note"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    private func editor(_ profile: RiderProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            field(language.t("profile.name"), text: Bindable(profile).name, prompt: language.t("profile.name.prompt"))
            field(language.t("profile.resort"), text: Bindable(profile).homeMountain, prompt: language.t("profile.resort.prompt"))
            Text(language.t("profile.hint"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            unitBlock(language.t("profile.speed"), metric: language.t("profile.unit.kmh"), imperial: language.t("profile.unit.mph"), isMetric: Bindable(profile).speedMetric)
            unitBlock(language.t("profile.distance"), metric: language.t("profile.unit.km"), imperial: language.t("profile.unit.mi"), isMetric: Bindable(profile).distanceMetric)
            unitBlock(language.t("profile.altitude"), metric: language.t("profile.unit.m"), imperial: language.t("profile.unit.ft"), isMetric: Bindable(profile).altitudeMetric)
            Toggle(isOn: Bindable(profile).keepScreenOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.t("profile.screen")).font(.headline)
                    Text(language.t("profile.screen.detail")).font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            locationCard
            Button {
                note = controller.toggleSampleDay()
            } label: {
                rowLabel(language.t("profile.sample"), language.t("profile.sample.detail"), "sparkles")
            }
            .buttonStyle(.plain)
            Button(role: .destructive) { confirmErase = true } label: {
                rowLabel(language.t("profile.erase"), language.t("profile.erase.detail"), "trash")
            }
            .buttonStyle(.plain)
        }
        .onChange(of: profile.name) { _, _ in try? modelContext.save() }
        .onChange(of: profile.homeMountain) { _, _ in try? modelContext.save() }
        .onChange(of: profile.speedMetric) { _, _ in
            controller.use(prefs: profile.prefs)
            try? modelContext.save()
        }
        .onChange(of: profile.distanceMetric) { _, _ in
            controller.use(prefs: profile.prefs)
            try? modelContext.save()
        }
        .onChange(of: profile.altitudeMetric) { _, _ in
            controller.use(prefs: profile.prefs)
            try? modelContext.save()
        }
        .onChange(of: profile.keepScreenOn) { _, _ in try? modelContext.save() }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func unitBlock(_ title: String, metric: String, imperial: String, isMetric: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            Picker(title, selection: isMetric) {
                Text(metric).tag(true)
                Text(imperial).tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("profile.location")).font(.headline)
            Text(locationCopy).font(.subheadline).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Button(language.t("profile.location.open")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var locationCopy: String {
        switch controller.auth {
        case .authorizedAlways: return language.t("profile.location.always")
        case .authorizedWhenInUse: return language.t("profile.location.wheninuse")
        case .denied, .restricted: return language.t("profile.location.denied")
        case .notDetermined: return language.t("profile.location.unknown")
        default: return language.t("profile.location.other")
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.t("profile.about.title")).font(.headline)
            Text(language.t("profile.about.1"))
            Text(language.t("profile.about.2"))
            Text(language.t("profile.about.3"))
            Text(language.t("profile.about.4"))
            Text(language.t("profile.about.5"))
        }
        .font(.subheadline)
        .foregroundStyle(Theme.muted)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rowLabel(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.text)
                Text(detail).font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
