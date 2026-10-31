import LingoCore
import SwiftUI

/// Navigation-only placeholders. No teacher, account, server or daily-plan logic is introduced.
enum AppSection: String, CaseIterable, Identifiable {
    case today, conversations, dictionary, progress, teacher
    var id: Self { self }
    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .conversations: "Conversations"
        case .dictionary: "Vocabulary"
        case .progress: "Progress"
        case .teacher: "Teacher"
        }
    }
    var symbol: String {
        switch self {
        case .today: "house"
        case .conversations: "bubble.left.and.bubble.right"
        case .dictionary: "book.closed"
        case .progress: "chart.bar"
        case .teacher: "sparkles"
        }
    }
}

struct PlannedSectionView: View {
    let section: AppSection
    var onContinue: () -> Void = {}
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                HStack {
                    Text(section.title).font(Theme.F.title)
                    Spacer()
                    Text("Coming soon").font(Theme.F.chip).foregroundStyle(Theme.C.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.C.surfaceCard, in: Capsule())
                }
                Text("Preview of a planned section. These features are not available yet.")
                    .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                if section == .today {
                    Text("Daily plan · 4 × 30 min").font(Theme.F.panelTitle)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        planCard("German · At the doctor's", lang: .de)
                        planCard("English · IELTS Part 2", lang: .en)
                        planCard("German · Free conversation", lang: .de)
                        planCard("English · Job interview", lang: .en)
                    }
                    SettingsCard(title: "Warm-up") {
                        Text("Your words and mistakes, ready for another try.")
                            .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                        Label("Coming soon", systemImage: "clock").font(Theme.F.chip)
                    }
                    Button("Continue conversation", action: onContinue)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    let cards: [LocalizedStringKey] = switch section {
                    case .teacher: ["Warm-up", "Scenarios", "German B1 exam", "IELTS Speaking", "Weekly report", "What Lingo knows about me"]
                    case .progress: ["Practice time", "Words and mistakes", "Weekly report"]
                    default: ["Saved phrases", "Language filter", "Listen and repeat"]
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(cards.enumerated()), id: \.offset) { index, title in
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: symbol(for: index)).font(.system(size: 24))
                                    .foregroundStyle(index.isMultiple(of: 2) ? Theme.C.accentGerman : Theme.C.accentEnglish)
                                Text(title).font(Theme.F.panelTitle)
                                Label("Coming soon", systemImage: "clock").font(Theme.F.subtitle)
                                    .foregroundStyle(Theme.C.textSecondary)
                            }
                            .padding(24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
                            .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
                            .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
                        }
                    }
                    if section == .dictionary {
                        Text("Your existing saved phrases are available in Hints → Vocabulary ★.")
                            .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                        Button("Open conversation", action: onContinue).buttonStyle(.bordered)
                    }
                }
            }.padding(32)
        }
        .foregroundStyle(Theme.C.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
    }
    private func symbol(for index: Int) -> String {
        let symbols: [String] = switch section {
        case .teacher: ["rectangle.on.rectangle", "bubble.left.and.bubble.right", "graduationcap", "mic", "calendar", "person.text.rectangle"]
        case .progress: ["chart.bar", "book.closed", "calendar"]
        default: ["star", "line.3.horizontal.decrease.circle", "speaker.wave.2"]
        }
        return symbols[index % symbols.count]
    }
    private func planCard(_ title: LocalizedStringKey, lang: Lang) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(lang.tag).font(Theme.F.chip).foregroundStyle(Theme.accent(lang))
            Text(title).font(Theme.F.hintPhrase)
            HStack { Text("30 min"); Spacer(); Text("Coming soon") }
                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
        }
        .padding(20).frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}
