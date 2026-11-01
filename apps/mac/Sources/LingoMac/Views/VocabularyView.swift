import LingoCore
import SwiftUI

/// "Vocabulary" (LINGO-08 VR-11; layout from design/redesign-2026/04-mac/mac-dictionary-starred-*.png, tokens from DESIGN.md):
/// language filter, search, add one item or a pasted list, one card per item with statistics, ▶, ★, edit, remove and "Practise".
struct VocabularyView: View {
    @Bindable var model: AppModel
    @State private var text = ""
    @State private var translation = ""
    @State private var addLang: Lang = .de
    @State private var translating = false
    @State private var pasting = false
    @State private var editing: VocabItem?
    @State private var removing: VocabItem?

    private var lang: Lang { model.vocabularyFilter ?? addLang }

    private var items: [VocabItem] { Self.shown(model.vocabulary, filter: model.vocabularyFilter, search: model.vocabularySearch) }

    /// Items of the filter language (nil = all) whose text or translation contains the search (normalised), newest first.
    nonisolated static func shown(_ all: [VocabItem], filter: Lang?, search: String) -> [VocabItem] {
        let q = VocabularyText.normalize(search)
        return all
            .filter { filter == nil || $0.lang == filter }
            .filter { q.isEmpty || VocabularyText.normalize($0.text + " " + $0.translation).contains(q) }
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
    }

    var body: some View {
        let shown = items
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                Text("Vocabulary").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
                HStack(spacing: Theme.S.s16) {
                    VocabularyFilter(selection: $model.vocabularyFilter).frame(width: Theme.S.sidebarWidth + Theme.S.hintsWidth / 2)
                    Spacer()
                    TextField("Search", text: $model.vocabularySearch).textFieldStyle(.roundedBorder).frame(width: Theme.S.sidebarWidth)
                }
                addCard
                if shown.isEmpty { emptyState } else {
                    ForEach(shown) { item in
                        VocabularyCard(item: item, services: model.services,
                                       onEdit: { editing = item }, onRemove: { removing = item })
                    }
                }
            }
            .padding(Theme.S.s32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.C.bgWindow)
        .onAppear { model.vocabularyNote = nil }
        .environment(\.studyLanguage, lang)
        .sheet(item: $editing) { item in
            VocabularyEditView(item: item, onSave: { t, tr, n, ex in
                model.services?.updateVocabulary(item, text: t, translation: tr, note: n, example: ex); editing = nil
            }, onCancel: { editing = nil })
        }
        .sheet(isPresented: $pasting) {
            VocabularyPasteView(lang: lang, askLanguage: model.vocabularyFilter == nil, onAdd: { target, parsed in
                pasting = false
                model.services?.addVocabulary(lang: target, entries: parsed.entries, source: .list, rejected: parsed.rejected)
            }, onCancel: { pasting = false })
        }
        .confirmationDialog(Text("Remove “\(removing?.text ?? "")”?"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Remove", role: .destructive) { if let r = removing { model.services?.removeVocabulary(r) }; removing = nil }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            Text(removing?.source == .starred ? "The phrase is un-starred." : "Its statistics are removed too.")
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            HStack(spacing: Theme.S.s12) {
                TextField("Word, phrase or expression", text: $text).textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                TextField("Translation (optional)", text: $translation).textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                if model.vocabularyFilter == nil {
                    LanguageSegment(selection: $addLang).frame(width: Theme.S.sidebarWidth)
                }
            }
            HStack(spacing: Theme.S.s12) {
                Button("Add", action: add)
                    .buttonStyle(.borderedProminent).tint(Theme.accent(lang))
                    .accessibilityLabel(model.vocabularyFilter == nil ? Text("Add to \(lang == .de ? String(localized: "German") : String(localized: "English"))") : Text("Add"))
                    .disabled(VocabularyText.normalize(text).isEmpty)
                Button(translating ? "Translating…" : "Translate") {
                    let t = text, l = lang
                    translating = true
                    Task {
                        // A late result does not overwrite a translation of another (or a cleared) text.
                        if let r = await model.services?.translateDraft(t, from: l), text == t { translation = r }
                        translating = false
                    }
                }
                .disabled(VocabularyText.normalize(text).isEmpty || translating)
                .help("One request to the model; only when you click")
                Button("Paste a list…") { pasting = true }
                Spacer()
                if let note = model.vocabularyNote {
                    Text(note).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
        }
        .padding(Theme.S.s20)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            Text(model.vocabularySearch.isEmpty ? "No words yet" : "Nothing found").font(Theme.F.panelTitle).foregroundStyle(Theme.C.textPrimary)
            Text("Add words, phrases or expressions you want to practise, or paste a list (one per line, “word — translation”). Lingo weaves a few of them into every conversation; ★ phrases from the hints are here too.")
                .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.S.s24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    private func add() {
        guard !VocabularyText.normalize(text).isEmpty else { return }
        model.services?.addVocabulary(lang: lang, entries: [(text, translation)], source: .manual)
        text = ""; translation = ""
    }
}

/// German | English | All (VR-11).
struct VocabularyFilter: View {
    @Binding var selection: Lang?

    var body: some View {
        HStack(spacing: 0) {
            segment(.de, String(localized: "German"))
            segment(.en, String(localized: "English"))
            segment(nil, String(localized: "All"))
        }
        .padding(Theme.S.s4)
        .frame(height: Theme.R.segmentHeight)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.button))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
    }

    private func segment(_ lang: Lang?, _ title: String) -> some View {
        let on = selection == lang
        return Button { selection = lang } label: {
            Text(title).font(Theme.F.segment)
                .foregroundStyle(on ? (lang.map(Theme.accent) ?? Theme.C.textPrimary) : Theme.C.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if on { RoundedRectangle(cornerRadius: Theme.R.button).fill(lang.map(Theme.accentSurface) ?? Theme.C.surfaceControl) }
                }
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// One item: text, translation, statistics (VR-05), ▶ (R-27), ★ marker, edit / remove, "Practise".
struct VocabularyCard: View {
    let item: VocabItem
    let services: AppServices?
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let accent = Theme.accent(item.lang)
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack(alignment: .top, spacing: Theme.S.s16) {
                Image(systemName: "waveform").font(Theme.F.panelTitle).foregroundStyle(accent)
                    .frame(width: Theme.R.sendButton + Theme.S.s4, height: Theme.R.sendButton + Theme.S.s4)
                    .background(Theme.accentSurface(item.lang), in: RoundedRectangle(cornerRadius: Theme.R.button))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.S.s4) {
                    Text(item.text).font(Theme.F.panelTitle).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    Text("Offered \(item.offered) · used \(item.used) · mistakes \(item.mistakes)")
                        .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    Group {
                        if let d = item.lastPractised { Text("Last practised: \(d.formatted(date: .abbreviated, time: .omitted))") }
                        else { Text("Not practised yet") }
                    }
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textTertiary)
                    if !item.note.isEmpty { Text(item.note).font(Theme.F.meta).foregroundStyle(Theme.C.textTertiary) }
                }
                Spacer()
                round("speaker.wave.2", label: "Listen") { services?.playVocabulary(item) }
                if item.source == .starred {
                    round("star.fill", label: "Remove the star", tint: accent, action: onRemove)
                } else {
                    round("pencil", label: "Edit", action: onEdit)
                    round("trash", label: "Remove", action: onRemove)
                }
            }
            if !item.translation.isEmpty {
                Text(item.translation).font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                    .padding(Theme.S.s12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accentSurface(item.lang), in: RoundedRectangle(cornerRadius: Theme.R.button))
                    .textSelection(.enabled)
            }
            Button { services?.practise(item) } label: {
                Text("Practise").font(Theme.F.button).foregroundStyle(Theme.C.accentButtonText)
                    .frame(maxWidth: .infinity, minHeight: Theme.R.primaryButtonHeight)
                    .background(accent, in: RoundedRectangle(cornerRadius: Theme.R.button))
            }
            .buttonStyle(LingoButtonStyle())
            .help("Start a “My words” session with this item first")
        }
        .padding(Theme.S.s24)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .environment(\.studyLanguage, item.lang)
    }

    private func round(_ symbol: String, label: LocalizedStringKey, tint: Color = Theme.C.textSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(Theme.F.hintPhrase).foregroundStyle(tint)
                .frame(width: Theme.R.roundButton, height: Theme.R.roundButton)
                .background(Theme.C.surfaceControl, in: Circle())
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Edit an own item (VR-04): text (required, ≤ 120), translation, note, example.
struct VocabularyEditView: View {
    let item: VocabItem
    let onSave: (String, String, String, String) -> Void
    let onCancel: () -> Void
    @State private var text = ""
    @State private var translation = ""
    @State private var note = ""
    @State private var example = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Edit").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
            TextField("Word, phrase or expression", text: $text).textFieldStyle(.roundedBorder)
            TextField("Translation (optional)", text: $translation).textFieldStyle(.roundedBorder)
            TextField("Note (optional)", text: $note).textFieldStyle(.roundedBorder)
            TextField("Example (optional)", text: $example).textFieldStyle(.roundedBorder)
            if text.count > 120 { Text("The text is longer than 120 characters.").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger) }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(text, translation, note, example) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Theme.accent(item.lang))
                    .disabled(VocabularyText.normalize(text).isEmpty || text.count > 120)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 520)
        .background(Theme.C.bgWindow)
        .modifier(InterfaceAppearance())
        .onAppear { text = item.text; translation = item.translation; note = item.note; example = item.example }
    }
}

/// "Paste a list" (VR-03): one item per line, "word — translation"; a preview of what will be added.
struct VocabularyPasteView: View {
    let lang: Lang
    /// With the filter on "All" the sheet asks for the language (VR-03).
    var askLanguage = false
    let onAdd: (Lang, VocabularyText.ParsedList) -> Void
    let onCancel: () -> Void
    @State private var pasted = ""
    @State private var target: Lang?

    var body: some View {
        let parsed = VocabularyText.parseList(pasted)
        let chosen = target ?? lang
        return VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Paste a list").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
            if askLanguage {
                LanguageSegment(selection: Binding(get: { chosen }, set: { target = $0 })).frame(width: Theme.S.sidebarWidth)
            } else {
                Text(chosen == .de ? "Language: German" : "Language: English").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            Text("One item per line. A translation may follow after “ — ”, “ – ”, “ - ”, a tab or “: ”; bullets and numbers are removed. At most 200 lines, 120 characters per item.")
                .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $pasted)
                .accessibilityLabel("Paste a list")
                .font(Theme.F.rowTitle).frame(minHeight: Theme.R.hintCardMinHeight * 2)
                .scrollContentBackground(.hidden).padding(Theme.S.s4)
                .background(Theme.C.surfaceInput, in: RoundedRectangle(cornerRadius: Theme.R.button))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
            Text("Recognised: \(parsed.entries.count) · rejected: \(parsed.rejected)").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Add") { onAdd(chosen, parsed) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Theme.accent(chosen))
                    .disabled(parsed.entries.isEmpty)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 520)
        .background(Theme.C.bgWindow)
        .modifier(InterfaceAppearance())
        .environment(\.studyLanguage, chosen)
    }
}
