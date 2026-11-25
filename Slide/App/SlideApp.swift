import SwiftData
import SwiftUI
import UIKit

@main
struct SlideApp: App {
    @State private var controller = SlideServices.controller
    @State private var language = SlideServices.language

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(controller)
                .environment(language)
                .environment(\.locale, language.swiftUILocale)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(AppContainer.shared)
    }
}

enum AppContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: SkiDay.self, TrickEntry.self, RiderProfile.self)
        } catch {
            do {
                let memory = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: SkiDay.self,
                    TrickEntry.self,
                    RiderProfile.self,
                    configurations: memory
                )
            } catch {
                fatalError("Slide could not open its local store.")
            }
        }
    }()
}

struct MainTabView: View {
    @Environment(TrackingController.self) private var controller
    @Environment(LanguageSettings.self) private var language
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [RiderProfile]
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TrackingView()
                .tag(0)
                .tabItem { Label(language.t("tab.tracking"), systemImage: "gauge.with.needle.fill") }
            PlacesMapView()
                .tag(1)
                .tabItem { Label(language.t("tab.map"), systemImage: "map.fill") }
            HistoryView()
                .tag(2)
                .tabItem { Label(language.t("tab.history"), systemImage: "clock.arrow.circlepath") }
            FreestyleView()
                .tag(3)
                .tabItem { Label(language.t("tab.freestyle"), systemImage: "figure.skiing.downhill") }
            ProfileView()
                .tag(4)
                .tabItem { Label(language.t("tab.profile"), systemImage: "person.crop.circle") }
        }
        .onAppear {
            controller.bind(context: modelContext, language: language)
            controller.use(prefs: profiles.first?.prefs ?? .metric)
            _ = DayStore.profile(in: modelContext)
            syncIdle()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { controller.flush() }
            if phase == .active {
                controller.refreshRecovery()
                syncIdle()
            }
        }
        .onChange(of: controller.activity) { _, _ in syncIdle() }
        .onChange(of: profiles.first?.keepScreenOn) { _, _ in syncIdle() }
        .onChange(of: profiles.first?.speedMetric) { _, _ in
            controller.use(prefs: profiles.first?.prefs ?? .metric)
        }
        .onChange(of: controller.notice) { _, note in
            switch note {
            case .gpxImported, .sessionImported, .fileUnknown, .fileUnreadable, .memoryNotReady:
                tab = 2
            default:
                break
            }
        }
        .onOpenURL { url in
            controller.importURL(url)
        }
    }

    private func syncIdle() {
        let keep = profiles.first?.keepScreenOn ?? false
        UIApplication.shared.isIdleTimerDisabled = controller.activity == .tracking && keep
    }
}
