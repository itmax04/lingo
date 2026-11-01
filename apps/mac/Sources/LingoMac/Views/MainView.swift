import LingoCore
import SwiftUI

/// Three-column window (R-40): sidebar | feed + voice panel + input | hints.
struct MainView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= Theme.S.hintsCollapseWidth
            HStack(spacing: 0) {
                SidebarView(model: model, onNewSession: { model.showNewSession = true })
                ColumnDivider()
                if model.section == .conversations { center }
                else if model.section == .dictionary { VocabularyView(model: model) }
                else if model.section == .today { TodayView(model: model) }
                else if model.section == .teacher { TeacherView(model: model) }
                else { PlannedSectionView(section: model.section) { model.section = .conversations } }
                if model.section == .conversations && wide && model.hintsVisible {
                    ColumnDivider()
                    hints
                }
            }
            .overlay(alignment: .trailing) {
                // R-40: below a width of 1280 the hints slide out over the feed.
                if model.section == .conversations && !wide && model.hintsVisible {
                    HStack(spacing: 0) { ColumnDivider(); hints }
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                }
            }
        }
        .background(Theme.C.bgWindow)
        .modifier(InterfaceAppearance())
        .sheet(item: $model.editing) { m in
            EditMessageView(message: m, onSave: { t in model.editing = nil; model.services?.editMessage(m.id, text: t) },
                            onRegenerate: { t in
                                model.editing = nil
                                if t != m.text { model.services?.editMessage(m.id, text: t) }
                                model.services?.regenerate(userMessageID: m.id)
                            },
                            onCancel: { model.editing = nil })
        }
        .sheet(isPresented: $model.showNewSession) {
            NewSessionView(lang: model.langFilter, lastCorrections: model.services?.settings.lastCorrections ?? [],
                           vocabularyCount: { l in model.vocabulary.filter { $0.lang == l }.count },
                           onStart: { s, t in model.showNewSession = false; model.section = .conversations; model.services?.createSession(s, title: t) },
                           onCancel: { model.showNewSession = false })
        }
    }

    private var hints: some View {
        HintsPanel(phrases: model.phrases, starred: model.starred, corrections: model.corrections,
                   dictionary: model.dictionary.filter { $0.lang == (model.selectedSession?.settings.lang ?? model.langFilter) },
                   onPlay: { model.services?.playPhrase($0) }, onStar: { model.services?.toggleStar($0) },
                   onClose: { model.hintsVisible = false })
    }

    private var center: some View {
        VStack(spacing: 0) {
            ChatHeader(title: model.selectedSession?.title ?? "Lingo",
                       subtitle: model.selectedSession?.settings.subtitle ?? String(localized: "Create a session: “New session”"),
                       sourceLabel: model.sourceLabel, online: model.online, memoryNote: model.memoryNote,
                       sourceMenu: AnyView(SourceMenu(model: model)), settingsMenu: AnyView(SessionMenu(model: model)))
            if let b = model.banner {
                Text(b).font(Theme.F.rowMeta).foregroundStyle(Theme.C.statusDanger).padding(Theme.S.s8)
                    .onTapGesture { model.banner = nil }
            }
            MessageList(messages: model.displayMessages, showInlineCorrections: model.selectedSession?.settings.corrections.contains(.inline) ?? false, isSpeaking: model.voiceState == .speaking, studyLanguage: model.selectedSession?.settings.lang, onTap: { m in model.services?.tapped(m) }, onStar: { model.services?.toggleStar($0) }, translations: model.translations, onTranslate: { model.services?.translate($0) }, onHideTranslation: { model.services?.hideTranslation($0) }, onCopy: { model.services?.copyToPasteboard($0) })
            VStack(spacing: Theme.S.s16) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VoicePanel(state: model.voiceState, levels: model.levels, lang: model.studyLanguage, unavailable: model.voiceUnavailableReason(now: context.date),
                           onMic: { model.services?.micTapped() }, onPause: { model.services?.pauseTapped() },
                           onEnd: { model.services?.endTapped() },
                           extraControls: AnyView(VoiceToggles(model: model)))
                    .disabled(!model.disabledReason.isEmpty)
                    .help(model.disabledReason)
                }
                if let sid = model.selectedSessionID, let sum = model.history.warmupSummary(session: sid), sum.reviewed > 0,
                   model.history.warmupState(session: sid, now: Date())?.finished == true {
                    WarmupEndCard(summary: sum, onSuspend: { model.services?.setCardSuspended($0, $1) }, suspended: model.history.suspendedCards)
                }
                if model.selectedSession?.state == .ended {
                    FinishedSessionCard(onContinue: { model.services?.continueSession() }, onNew: { model.showNewSession = true })
                } else if !model.disabledReason.isEmpty, model.selectedSession != nil {
                    Text(model.disabledReason).font(Theme.F.rowMeta).foregroundStyle(Theme.C.statusDanger)
                }
                InputBar(text: $model.draft, enabled: model.disabledReason.isEmpty,
                         disabledReason: model.disabledReason,
                         onSend: { model.services?.sendText() })
            }
            .padding(.horizontal, Theme.S.columnPadding)
            .padding(.bottom, Theme.S.columnPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
        .overlay(alignment: .topTrailing) {
            if !model.hintsVisible {
                Button { model.hintsVisible = true } label: {
                    Image(systemName: "book").font(.system(size: 18)).foregroundStyle(Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Show hints")
                .padding(Theme.S.s8)
            }
        }
    }
}

/// Voice panel toggles (R-42): continuous mode, "I'm speaking Russian" (R-09, ⌥R), "Slow pace" (R-15).
struct VoiceToggles: View {
    @Environment(\.studyLanguage) private var studyLanguage
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: Theme.S.s8) {
            toggle("Continuous", symbol: "infinity", on: model.continuous) { model.services?.toggleContinuous() }
            toggle("In Russian", symbol: "character.bubble", on: model.russianOnce) { model.services?.toggleRussian() }
            toggle("Slowly", symbol: "tortoise", on: model.slowPace) { model.services?.toggleSlowPace() }
        }
    }

    func toggle(_ title: LocalizedStringKey, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                Text(title).font(Theme.F.caption)
            }
            .foregroundStyle(on ? Theme.accent(studyLanguage) : Theme.C.textSecondary)
            .padding(.horizontal, 12).frame(height: 28)
            .background(on ? Theme.accentSurface(studyLanguage) : Theme.C.surfaceControl, in: Capsule())
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Source badge (R-32): "Auto (chain)" or a specific chain step.
struct SourceMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            let llm = model.services?.settings.llm
            Button((llm?.pinnedEntryID == nil ? "✓ " : "") + String(localized: "Auto (chain)")) { model.services?.pin(nil) }
            Divider()
            ForEach(llm?.chain.filter(\.enabled) ?? []) { e in
                Button((llm?.pinnedEntryID == e.id ? "✓ " : "") + StepInfo(provider: e.provider, model: e.model, keyID: "").label) { model.services?.pin(e.id) }
            }
        } label: {
            SourceChip(label: model.sourceLabel, ok: model.online)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Reply source: \(model.sourceLabel)")
    }
}

/// Header gear: the session's correction modes (R-20), "Slow pace" (R-15), the assistant's memory (R-04).
struct SessionMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            if let s = model.selectedSession {
                Section("Error correction") {
                    ForEach(CorrectionMode.allCases, id: \.self) { c in
                        Button((s.settings.corrections.contains(c) ? "✓ " : "") + c.title) { model.services?.toggleCorrection(c) }
                    }
                }
                Button((model.slowPace ? "✓ " : "") + String(localized: "Slow pace")) { model.services?.toggleSlowPace() }
                if !s.settings.isVocabularyFocus {
                    Button((s.settings.vocabularyOn ? "✓ " : "") + String(localized: "Use my vocabulary")) { model.services?.toggleVocabulary() }
                }
                Section(model.memoryNote ?? "") {}
            }
            Button("Lingo Settings…") { NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil) }
        } label: {
            Image(systemName: "gearshape").font(.system(size: 18)).foregroundStyle(Theme.C.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Session settings")
    }
}
