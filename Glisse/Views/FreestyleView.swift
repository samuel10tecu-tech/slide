import SwiftData
import SwiftUI

struct FreestyleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [TrickEntry]
    @State private var level: Trick.Level?
    @State private var query = ""

    private var learnedIDs: Set<String> {
        Set(entries.filter(\.learned).map(\.trickId))
    }

    private var filtered: [Trick] {
        TrickLibrary.tricks.filter { trick in
            let levelOK = level == nil || trick.level == level
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryOK = text.isEmpty
                || trick.name.localizedCaseInsensitiveContains(text)
                || trick.summary.localizedCaseInsensitiveContains(text)
                || trick.category.rawValue.localizedCaseInsensitiveContains(text)
            return levelOK && queryOK
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    progress
                    TextField("Rechercher un trick", text: $query)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    chips
                    if let pinned = TrickLibrary.trick("park-rules"), query.isEmpty && level == nil {
                        NavigationLink {
                            TrickDetailView(trick: pinned)
                        } label: {
                            Banner(
                                text: "Avant le park : les règles, le casque, et comment tomber. Lis ça une fois.",
                                systemImage: "shield.fill",
                                tint: Theme.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if filtered.isEmpty {
                        Text("Aucun trick ne correspond.")
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 12)
                    }
                    ForEach(filtered) { trick in
                        NavigationLink {
                            TrickDetailView(trick: trick)
                        } label: {
                            trickRow(trick)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle("Freestyle")
        }
    }

    private var progress: some View {
        let total = TrickLibrary.tricks.count
        let done = learnedIDs.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done) sur \(total)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Spacer()
                Text("tricks cochés")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: total == 0 ? 0 : proxy.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 8)
            Text("La bibliothèque est dans l'app. Rien n'est téléchargé.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Tous", selected: level == nil) { level = nil }
                ForEach(Trick.Level.allCases) { item in
                    chip(item.rawValue, selected: level == item) {
                        level = level == item ? nil : item
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.accent : Theme.surface, in: Capsule())
                .foregroundStyle(selected ? Color.black : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private func trickRow(_ trick: Trick) -> some View {
        HStack(spacing: 12) {
            Image(systemName: learnedIDs.contains(trick.id) ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(learnedIDs.contains(trick.id) ? Theme.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(trick.name)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    Text(trick.level.rawValue)
                        .foregroundStyle(Theme.levelColor(trick.level))
                    Text("·")
                    Text(trick.category.rawValue)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TrickDetailView: View {
    var trick: Trick
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [TrickEntry]
    @State private var note = ""
    @State private var loaded = false

    private var entry: TrickEntry? {
        entries.first { $0.trickId == trick.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text(trick.level.rawValue)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.levelColor(trick.level).opacity(0.16), in: Capsule())
                        .foregroundStyle(Theme.levelColor(trick.level))
                    Text(trick.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                Text(trick.summary)
                    .font(.body)
                    .foregroundStyle(Theme.text)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Comment faire")
                        .font(.headline)
                    ForEach(Array(trick.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.heavy))
                                .frame(width: 22, height: 22)
                                .background(Theme.accent, in: Circle())
                                .foregroundStyle(.black)
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Banner(text: trick.safety, systemImage: "shield.lefthalf.filled", tint: Theme.orange)
                if !trick.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("À retenir")
                            .font(.headline)
                        ForEach(trick.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.text)
                            }
                        }
                    }
                }
                learnedToggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tes notes")
                        .font(.headline)
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: note) { _, newValue in
                            guard loaded else { return }
                            let row = ensureEntry()
                            row.note = newValue
                            row.updatedAt = Date()
                            try? modelContext.save()
                        }
                }
            }
            .padding(20)
        }
        .background(ScreenBackground())
        .navigationTitle(trick.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            note = entry?.note ?? ""
            loaded = true
        }
    }

    private var learnedToggle: some View {
        let on = entry?.learned ?? false
        return Button {
            let row = ensureEntry()
            row.learned.toggle()
            row.learnedAt = row.learned ? Date() : nil
            row.updatedAt = Date()
            try? modelContext.save()
        } label: {
            HStack {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(on ? "Je le maîtrise" : "Pas encore")
                        .font(.headline)
                    if let date = entry?.learnedAt, on {
                        Text(FormatFR.dayTitle(date))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("Coche quand tu le poses proprement, pas au premier essai.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(on ? Theme.accent : Theme.text)
        }
        .buttonStyle(.plain)
    }

    @discardableResult
    private func ensureEntry() -> TrickEntry {
        if let entry { return entry }
        let trickID = trick.id
        let stored = (try? modelContext.fetch(FetchDescriptor<TrickEntry>())) ?? []
        if let found = stored.first(where: { $0.trickId == trickID }) {
            return found
        }
        let created = TrickEntry(trickId: trick.id, learned: false, learnedAt: nil, note: note)
        modelContext.insert(created)
        return created
    }
}
