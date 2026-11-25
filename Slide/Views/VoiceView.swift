import AppIntents
import SwiftUI

struct VoiceView: View {
    @Environment(LanguageSettings.self) private var language

    private var phrases: [(String, any AppIntent)] {
        [
            (language.t("siri.phrase.max"), MaxSpeedTodayIntent()),
            (language.t("siri.phrase.distance"), DistanceTodayIntent()),
            (language.t("siri.phrase.now"), CurrentSpeedIntent()),
            (language.t("siri.phrase.ago"), SpeedAgoIntent()),
            (language.t("siri.phrase.runs"), RunsTodayIntent()),
            (language.t("siri.phrase.start"), StartTrackingIntent()),
            (language.t("siri.phrase.stop"), StopTrackingIntent()),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(language.t("voice.lead"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    AudioCoachCard(language: language)
                    Text(language.t("voice.siri"))
                        .font(.title3.weight(.heavy))
                    Text(language.t("voice.siri.help"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    ForEach(Array(phrases.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("“\(item.0)”")
                                .font(.headline)
                                .foregroundStyle(Theme.snow)
                            Button {
                                if let url = URL(string: "shortcuts://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label(language.t("voice.add"), systemImage: "mic.fill")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accent, in: Capsule())
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle(language.t("voice.title"))
        }
    }
}
