import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingController.self) private var controller
    @Query private var profiles: [RiderProfile]
    @State private var confirmErase = false
    @State private var note: String?

    private var profile: RiderProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let profile {
                        editor(profile)
                    }
                    about
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle("Profil")
            .onAppear {
                _ = DayStore.profile(in: modelContext)
            }
        }
        .alert("Profil", isPresented: Binding(
            get: { note != nil },
            set: { if !$0 { note = nil } }
        )) {
            Button("OK", role: .cancel) { note = nil }
        } message: {
            Text(note ?? "")
        }
        .confirmationDialog("Tout effacer ?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Effacer les sorties et les tricks", role: .destructive) {
                controller.eraseAllDaysAndTricks()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le prénom et les unités restent. Cette action ne quitte pas le téléphone : il n'y a pas de copie en ligne.")
        }
    }

    private func editor(_ profile: RiderProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Prénom", text: Bindable(profile).name, prompt: "Ton prénom")
            field("Station", text: Bindable(profile).homeMountain, prompt: "Ta station")
            Text("Le prénom apparaît sur l'image partagée. La station est proposée au démarrage d'une sortie.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            unitBlock("Vitesse", metric: "km/h", imperial: "mph", isMetric: Bindable(profile).speedMetric)
            unitBlock("Distance", metric: "km", imperial: "mi", isMetric: Bindable(profile).distanceMetric)
            unitBlock("Altitude", metric: "mètres", imperial: "pieds", isMetric: Bindable(profile).altitudeMetric)

            Toggle(isOn: Bindable(profile).keepScreenOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Garder l'écran allumé")
                        .font(.headline)
                    Text("Pendant le suivi seulement. Ça vide la batterie plus vite, surtout dans le froid.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            locationCard

            Button {
                note = controller.toggleSampleDay()
            } label: {
                rowLabel("Journée d'exemple", "Ajoute ou retire une trace fictive pour explorer l'historique.", "sparkles")
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                confirmErase = true
            } label: {
                rowLabel("Tout effacer", "Sorties et checklist. Irréversible.", "trash")
            }
            .buttonStyle(.plain)
        }
        .onChange(of: profile.name) { _, _ in try? modelContext.save() }
        .onChange(of: profile.homeMountain) { _, _ in try? modelContext.save() }
        .onChange(of: profile.speedMetric) { _, _ in try? modelContext.save() }
        .onChange(of: profile.distanceMetric) { _, _ in try? modelContext.save() }
        .onChange(of: profile.altitudeMetric) { _, _ in try? modelContext.save() }
        .onChange(of: profile.keepScreenOn) { _, _ in try? modelContext.save() }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func unitBlock(_ title: String, metric: String, imperial: String, isMetric: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
            Picker(title, selection: isMetric) {
                Text(metric).tag(true)
                Text(imperial).tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position")
                .font(.headline)
            Text(locationCopy)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les réglages iPhone") {
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
        case .authorizedAlways:
            return "Autorisée en permanence. Le suivi peut continuer écran verrouillé, et il s'arrête quand tu termines."
        case .authorizedWhenInUse:
            return "Autorisée seulement quand l'app est ouverte. Pour la poche, choisis « Toujours »."
        case .denied, .restricted:
            return "Bloquée. Sans ça, pas de vitesse ni de trace."
        case .notDetermined:
            return "Pas encore demandée. Le bouton Démarrer affiche la demande iOS."
        default:
            return "Vérifie l'autorisation dans Réglages."
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sans compte")
                .font(.headline)
            Text("Glisse ne crée pas de compte et n'envoie rien sur Internet. Les traces, les tricks et le prénom restent dans le téléphone.")
            Text("L'airtime est une estimation de l'accéléromètre : utile pour comparer tes sauts, pas une mesure de labo.")
            Text("En montagne le froid vide la batterie. Garde le téléphone au chaud, dans une poche intérieure, et pars chargé. Le mode économie d'énergie peut couper le GPS.")
            Text("Une barre ou une pastille bleue peut s'afficher pendant le suivi : c'est iOS qui montre que le GPS tourne.")
            Text("Avec un Apple ID gratuit, l'app installée depuis Xcode doit être réinstallée environ tous les 7 jours. Partager l'app elle-même (TestFlight) demande un compte développeur payant, au nom d'un adulte.")
        }
        .font(.subheadline)
        .foregroundStyle(Theme.muted)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rowLabel(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
