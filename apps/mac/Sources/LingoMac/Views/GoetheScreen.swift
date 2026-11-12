import LingoCore
import SwiftUI

extension GoetheCriterion {
    /// The criterion names of the card and the right panel (BR-27a). Lingo's own wording of the official criteria; no pronunciation row exists.
    var title: LocalizedStringKey {
        switch self {
        case .e1, .e2, .e3: "Task fulfilment"
        case .i1: "Interaction"
        case .k2: "Coherence"
        case .w1, .w2: "Vocabulary"
        case .s1, .s2: "Structures"
        }
    }
}

extension ExamCategory {
    var title: LocalizedStringKey {
        switch self {
        case .alltag: "Everyday life"
        case .arbeit: "Work"
        case .freizeit: "Leisure"
        case .umwelt: "Environment"
        case .gesundheit: "Health"
        }
    }
    var symbol: String {
        switch self {
        case .alltag: "house"
        case .arbeit: "briefcase"
        case .freizeit: "figure.walk"
        case .umwelt: "leaf"
        case .gesundheit: "heart"
        }
    }
}

/// A row of mutually exclusive choices in the style of DESIGN.md §5 (segment height 36 pt, radius 12 pt). Not hidden when locked: disabled.
struct SegmentBar<T: Hashable>: View {
    let items: [(value: T, title: Text)]
    @Binding var selection: T
    @Environment(\.studyLanguage) private var studyLanguage
    var body: some View {
        HStack(spacing: Theme.S.s4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.value == selection
                Button { selection = item.value } label: {
                    item.title.font(Theme.F.segment)
                        .foregroundStyle(on ? Theme.C.accentButtonText : Theme.C.textPrimary)
                        .padding(.horizontal, Theme.S.s20).frame(height: Theme.R.segmentHeight)
                        .background(on ? Theme.accent(studyLanguage) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.R.button))
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Theme.S.s4)
        .background(Theme.C.surfaceControl, in: RoundedRectangle(cornerRadius: Theme.R.card))
    }
}

/// LINGO-10 BR-33…BR-36: the German B1 exam screen, opened from the Teacher card. Part 1: the Training and Debriefs tabs and the right panel.
/// The Mock tab, its preparation and the locking of the tabs during a Mock arrive in G-5b.
struct GoetheScreen: View {
    @Bindable var model: AppModel
    @Environment(\.studyLanguage) private var studyLanguage
    /// Below 1280 pt of window width the right panel slides over the list (DESIGN.md §4).
    @State private var panelOpen = false
    @State private var showPhrases = false
    @State private var showPlan = false

    private let lang = Lang.de

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width + Theme.S.sidebarWidth + Theme.R.stroke >= Theme.S.hintsCollapseWidth
            let training = model.goetheTab == .training
            HStack(spacing: 0) {
                main(wide: wide)
                if training && wide {
                    ColumnDivider()
                    panel(docked: true)
                }
            }
            .overlay(alignment: .trailing) {
                if training && !wide && panelOpen {
                    HStack(spacing: 0) { ColumnDivider(); panel(docked: false) }
                }
            }
        }
        .foregroundStyle(Theme.C.textPrimary)
        .background(Theme.C.bgWindow)
        .environment(\.studyLanguage, lang)
    }

    // MARK: Main column

    private func main(wide: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                BannerLine(model: model)
                header
                SegmentBar(items: [(AppModel.GoetheTab.training, Text("Training")), (.debriefs, Text("Debriefs"))], selection: $model.goetheTab)
                if model.goetheTab == .training { training(wide: wide) } else { debriefs }
            }.padding(Theme.S.s32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            Button { model.showGoethe = false } label: {
                Label("Teacher", systemImage: "chevron.left").font(Theme.F.button)
            }.buttonStyle(LingoButtonStyle()).accessibilityLabel("Back to Teacher")
            HStack(spacing: Theme.S.s16) {
                Image(systemName: "graduationcap").font(Theme.F.title).foregroundStyle(Theme.accent(lang))
                    .frame(width: Theme.R.primaryButtonHeight, height: Theme.R.primaryButtonHeight)
                    .background(Theme.accentSurface(lang), in: RoundedRectangle(cornerRadius: Theme.R.card)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.S.s4) {
                    Text(verbatim: "Goethe-Zertifikat B1 — Sprechen").font(Theme.F.title)
                    Text("Practise each part of the speaking exam, then read the debrief.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                }
            }
        }
    }

    // MARK: Training

    private var teil: Int { model.goetheTeil }
    private var tasks: [ExamTask] { GoetheHub.tasks(teil: teil, category: model.goetheCategory) }
    /// The task shown in the right panel: the chosen one when it is in the list, otherwise the first of the list.
    private var selected: ExamTask? { tasks.first { $0.id == model.goetheTask } ?? tasks.first }

    private func training(wide: Bool) -> some View {
        let practice = GoetheHub.practice(model.history)
        return VStack(alignment: .leading, spacing: Theme.S.s24) {
            steps
            VStack(alignment: .leading, spacing: Theme.S.s12) {
                Text("What to practise").font(Theme.F.panelTitle)
                SegmentBar(items: [(1, Text(verbatim: "Teil 1")), (2, Text(verbatim: "Teil 2")), (3, Text(verbatim: "Teil 3"))],
                           selection: Binding(get: { model.goetheTeil }, set: { model.goetheTeil = $0; model.goetheCategory = nil; model.goetheTask = nil }))
                chips
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: Theme.S.s12, alignment: .top)], spacing: Theme.S.s12) {
                ForEach(tasks) { t in taskCard(t, practice: practice[t.id], on: t.id == selected?.id, wide: wide) }
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("How the exam goes").font(Theme.F.panelTitle)
            HStack(alignment: .top, spacing: Theme.S.s8) {
                step(1, "Preparation", "Mock exam: 15 min, notes", on: false)
                step(2, "Introduction", "Mock exam: 1 min, not assessed", on: false)
                step(3, "Teil 1", "Planning together · 3 min", on: teil == 1)
                step(4, "Teil 2", "Presenting a topic · 3-4 min", on: teil == 2)
                step(5, "Teil 3", "Talking about the topic · 2 min", on: teil == 3)
            }
        }
        .padding(Theme.S.s20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }

    private func step(_ n: Int, _ title: LocalizedStringKey, _ caption: LocalizedStringKey, on: Bool) -> some View {
        VStack(spacing: Theme.S.s4) {
            Text(verbatim: "\(n)").font(Theme.F.button)
                .foregroundStyle(on ? Theme.C.accentButtonText : Theme.C.textPrimary)
                .frame(width: Theme.R.roundButton, height: Theme.R.roundButton)
                .background(on ? Theme.accent(lang) : Theme.C.surfaceControl, in: Circle())
            Text(title).font(Theme.F.hintPhrase)
            Text(caption).font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var chips: some View {
        HStack(spacing: Theme.S.s8) {
            chip("All topics", on: model.goetheCategory == nil) { model.goetheCategory = nil; model.goetheTask = nil }
            ForEach(GoetheHub.categories(teil: teil), id: \.self) { c in
                chip(c.title, on: model.goetheCategory == c) { model.goetheCategory = c; model.goetheTask = nil }
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: LocalizedStringKey, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.F.chip)
                .foregroundStyle(on ? Theme.accent(lang) : Theme.C.textSecondary)
                .padding(.horizontal, Theme.S.s12).frame(height: Theme.R.chipHeight)
                .background(on ? Theme.accentSurface(lang) : Theme.C.surfaceChip, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Theme.accent(lang) : Color.clear, lineWidth: Theme.R.stroke))
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func taskCard(_ t: ExamTask, practice: GoetheHub.Practice?, on: Bool, wide: Bool) -> some View {
        Button {
            model.goetheTask = t.id
            panelOpen = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.S.s8) {
                Image(systemName: t.category?.symbol ?? "text.bubble").font(.system(size: 20)).foregroundStyle(Theme.accent(lang)).accessibilityHidden(true)
                Text(verbatim: t.title ?? t.task).font(Theme.F.hintPhrase).multilineTextAlignment(.leading)
                if let gloss = t.gloss { Text(verbatim: gloss).font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).multilineTextAlignment(.leading) }
                Spacer(minLength: 0)
                if let practice {
                    Text("Practised: \(practice.count) · \(practice.last.formatted(.dateTime.day().month()))").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                } else {
                    Text("Not practised yet").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
            .padding(Theme.S.s16).frame(maxWidth: .infinity, minHeight: Theme.R.hintCardMinHeight + Theme.S.s24, alignment: .topLeading)
            .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.card).strokeBorder(on ? Theme.accent(lang) : Theme.C.borderSubtle, lineWidth: on ? 2 : Theme.R.stroke))
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Right panel (BR-35)

    private func panel(docked: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s16) {
                if let t = selected {
                    HStack {
                        Text("Selected topic").font(Theme.F.panelTitle)
                        Spacer()
                        if !docked { Button { panelOpen = false } label: { Image(systemName: "xmark") }.buttonStyle(LingoButtonStyle()).accessibilityLabel("Close") }
                    }
                    VStack(alignment: .leading, spacing: Theme.S.s4) {
                        Text(verbatim: t.title ?? t.task).font(Theme.F.panelTitle)
                        if let gloss = t.gloss { Text(verbatim: gloss).font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary) }
                    }
                    ColumnDivider(vertical: false)
                    Text("What will happen").font(Theme.F.hintPhrase)
                    Text(happens).font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Text("How it is assessed").font(Theme.F.hintPhrase)
                    VStack(alignment: .leading, spacing: Theme.S.s4) {
                        ForEach(GoetheCriterion.criteria(teil: teil), id: \.self) { c in Text(c.title).font(Theme.F.subtitle) }
                        Text("Lingo does not assess pronunciation.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).padding(.top, Theme.S.s4)
                    }
                    ColumnDivider(vertical: false)
                    disclosure(Text("Useful phrases for Teil \(teil)"), open: $showPhrases) {
                        ForEach(Array(ExamCatalog.goethePhrases(teil: teil).enumerated()), id: \.offset) { _, p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: p.de).font(Theme.F.hintPhrase).textSelection(.enabled)
                                Text(verbatim: p.ru).font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
                            }
                        }
                    }
                    if teil == 2 {
                        disclosure(Text("My presentation plan"), open: $showPlan) { notesField }
                    }
                    Button { model.services?.startGoetheTraining(teil: teil, task: t.id) } label: {
                        Text("Start training").font(Theme.F.button).foregroundStyle(Theme.C.accentButtonText)
                            .frame(maxWidth: .infinity, minHeight: Theme.R.primaryButtonHeight)
                            .background(Theme.accent(lang), in: RoundedRectangle(cornerRadius: Theme.R.button))
                    }
                    .buttonStyle(LingoButtonStyle())
                    .disabled(!model.online)
                    .accessibilityLabel(Text("Start training") + Text(": ") + Text(verbatim: t.title ?? t.task))
                    if !model.online { Text(model.disabledReason).font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger) }
                }
            }
            .padding(Theme.S.s20)
        }
        .frame(width: Theme.S.hintsWidth).frame(maxHeight: .infinity)
        .background(Theme.C.bgHints)
    }

    private var happens: LocalizedStringKey {
        switch teil {
        case 1: "You plan something together with Lingo. Lingo suggests, you answer and decide, and you cover the four points."
        case 2: "You present the topic on five slides. Lingo listens and answers briefly."
        default: "You listen to Lingo's talk, give feedback and ask a question, then answer one question about the topic."
        }
    }

    /// BR-22: memory only for the run; at most 2 000 characters; never sent anywhere.
    private var notesField: some View {
        TextEditor(text: Binding(get: { model.goetheNotes }, set: { model.goetheNotes = String($0.prefix(AppModel.notesLimit)) }))
            .font(Theme.F.subtitle).scrollContentBackground(.hidden).padding(Theme.S.s8)
            .frame(height: 140)
            .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.button))
            .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
            .accessibilityLabel("My presentation plan")
    }

    private func disclosure<Content: View>(_ title: Text, open: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            Button { open.wrappedValue.toggle() } label: {
                HStack {
                    title.font(Theme.F.hintPhrase)
                    Spacer()
                    Image(systemName: open.wrappedValue ? "chevron.down" : "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .padding(Theme.S.s12)
                .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.button))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
            }
            .buttonStyle(LingoButtonStyle())
            .accessibilityAddTraits(open.wrappedValue ? .isSelected : [])
            if open.wrappedValue { content() }
        }
    }

    // MARK: Debriefs (BR-36)

    private var debriefs: some View {
        let list = GoetheHub.debriefs(model.history)
        return VStack(alignment: .leading, spacing: Theme.S.s12) {
            if list.isEmpty {
                Text("No debriefs yet. Finish a part in Training and its debrief appears here.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                    .padding(.vertical, Theme.S.s24)
            }
            ForEach(list) { entry in
                Button {
                    model.langFilter = .de
                    model.selectedSessionID = entry.id
                    model.section = .conversations
                } label: {
                    HStack(spacing: Theme.S.s16) {
                        VStack(alignment: .leading, spacing: Theme.S.s4) {
                            Text(verbatim: entry.topic).font(Theme.F.hintPhrase)
                            Group {
                                if entry.format == .mock { Text("Mock exam") } else { Text("Training · Teil \(entry.teil ?? 0)") }
                            }.font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                        }
                        Spacer()
                        Text(entry.date.formatted(.dateTime.day().month().hour().minute())).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.C.textSecondary).accessibilityHidden(true)
                    }
                    .padding(Theme.S.s16)
                    .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
                    .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityElement(children: .combine)
            }
        }
    }
}
