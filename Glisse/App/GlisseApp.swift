import SwiftData
import SwiftUI
import UIKit

@main
struct GlisseApp: App {
    @State private var controller = TrackingController()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(controller)
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
                fatalError("Glisse ne peut pas ouvrir sa base locale.")
            }
        }
    }()
}

struct MainTabView: View {
    @Environment(TrackingController.self) private var controller
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [RiderProfile]
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TrackingView()
                .tag(0)
                .tabItem { Label("Suivi", systemImage: "gauge.with.needle.fill") }
            HistoryView()
                .tag(1)
                .tabItem { Label("Historique", systemImage: "clock.arrow.circlepath") }
            FreestyleView()
                .tag(2)
                .tabItem { Label("Freestyle", systemImage: "figure.skiing.downhill") }
            ProfileView()
                .tag(3)
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .onAppear {
            controller.bind(context: modelContext)
            _ = DayStore.profile(in: modelContext)
            syncIdle()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                controller.flush()
            }
            if phase == .active {
                controller.refreshRecovery()
                syncIdle()
            }
        }
        .onChange(of: controller.activity) { _, _ in
            syncIdle()
        }
        .onChange(of: profiles.first?.keepScreenOn) { _, _ in
            syncIdle()
        }
        .onChange(of: controller.importNote) { _, note in
            if note != nil { tab = 1 }
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
