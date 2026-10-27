import LingoCore
import SwiftUI

/// Left column (R-40): logo, "New session", language segment, "My sessions", sync status.
/// In the mockup the session rows are wider than the other column elements: 8 pt padding instead of 16.
private let sidebarListInset: CGFloat = -Theme.S.s8

struct SidebarView: View {
    @Bindable var model: AppModel
    var onNewSession: () -> Void = {}
    @State private var renaming: Session?
    @State private var renameText = ""
    @State private var deleting: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) { LingoMark().frame(width: 36, height: 36); Text("Lingo").font(Theme.F.logo) }
                .font(Theme.F.logo)
                .foregroundStyle(Theme.C.textPrimary)
                .padding(.top, Theme.S.s8)
                .padding(.bottom, Theme.S.s20)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    Button { model.section = section } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.symbol).frame(width: 20)
                            Text(section.title).font(Theme.F.rowTitle)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(model.section == section ? Theme.accent(model.studyLanguage) : Theme.C.textSecondary)
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(model.section == section ? Theme.C.surfaceRowSelected : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Theme.R.button))
                    }.buttonStyle(LingoButtonStyle())
                }
            }.padding(.bottom, 20)

            Button(action: onNewSession) {
                HStack(spacing: Theme.S.s16) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                    Text("New session").font(Theme.F.button)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.C.accentButtonText)
                .padding(.horizontal, Theme.S.s16)
                .frame(height: Theme.R.primaryButtonHeight)
                .background(Theme.accent(model.studyLanguage), in: RoundedRectangle(cornerRadius: Theme.R.button))
            }
            .buttonStyle(LingoButtonStyle())
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("New session")
            .padding(.bottom, Theme.S.s16)

            LanguageSegment(selection: $model.langFilter)
                .padding(.bottom, Theme.S.s24)

            Text("My sessions")
                .font(Theme.F.section)
                .foregroundStyle(Theme.C.textSecondary)
                .padding(.bottom, Theme.S.s8)

            ScrollView {
                LazyVStack(spacing: Theme.S.s4) {
                    ForEach(model.visibleSessions) { s in
                        SessionRow(session: s, selected: s.id == model.selectedSessionID, onSelect: {
                            model.section = .conversations
                            model.selectedSessionID = s.id
                            model.refreshSelection()
                        }, menu: AnyView(Menu {
                            SessionActionsContent(onRename: { renameText = s.title; renaming = s },
                                                  onReveal: { model.services?.revealJournal() },
                                                  onDelete: { deleting = s })
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 14)).foregroundStyle(Theme.C.textTertiary)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel("Session actions")))
                    }
                }
            }
            .scrollIndicators(.never)
            .padding(.horizontal, sidebarListInset)

            Spacer(minLength: 0)
            Button { NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil) } label: {
                Label("Settings…", systemImage: "gearshape").font(Theme.F.rowTitle)
                    .foregroundStyle(Theme.C.textSecondary)
            }.buttonStyle(LingoButtonStyle()).padding(.top, 12)
            Button {
                if case .unavailable = model.syncState { model.services?.chooseSyncFolder() }
                else if case .notConfigured = model.syncState { model.services?.chooseSyncFolder() }
                else { model.services?.syncNow() }
            } label: { SyncStatusLine(text: model.syncStatus) }
                .buttonStyle(LingoButtonStyle())
                .help("iCloud decides the delay between devices — sync is not instant (R-38)")
                .padding(.vertical, Theme.S.s12)
        }
        .padding(.horizontal, Theme.S.columnPadding)
        .frame(width: Theme.S.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.C.bgSidebar)
        .alert("Rename session", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") { if let s = renaming { model.services?.rename(s.id, renameText) }; renaming = nil }
        }
        .confirmationDialog("Delete session “\(deleting?.title ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let s = deleting { model.services?.delete(s.id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The session disappears on all devices after a sync. The messages stay in the journal (a tombstone event).")
        }
    }
}

/// English/Deutsch segment (DESIGN.md §5).
struct LanguageSegment: View {
    @Binding var selection: Lang

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Lang.studied, id: \.self) { lang in
                Button { selection = lang } label: {
                    Text(lang == .de ? String(localized: "German") : String(localized: "English"))
                        .font(Theme.F.segment)
                        .foregroundStyle(selection == lang ? Theme.accent(lang) : Theme.C.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selection == lang {
                                RoundedRectangle(cornerRadius: Theme.R.button).fill(Theme.accentSurface(lang))
                            }
                        }
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityAddTraits(selection == lang ? .isSelected : [])
            }
        }
        .padding(Theme.S.s4)
        .frame(height: Theme.R.segmentHeight)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.button))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
    }
}

/// Session row (DESIGN.md §5): icon, title, date, "…".
struct SessionRow: View {
    let session: Session
    let selected: Bool
    let onSelect: () -> Void
    var menu: AnyView = AnyView(Image(systemName: "ellipsis").font(.system(size: 14)).foregroundStyle(Theme.C.textTertiary)
        .accessibilityLabel("Session actions"))
    @State private var hover = false

    var body: some View {
        HStack(spacing: Theme.S.s12) {
            Image(systemName: session.settings.lang == .de ? "bubble.left" : "bubble.right")
                .font(.system(size: 16))
                .foregroundStyle(Theme.C.textTertiary)
            VStack(alignment: .leading, spacing: Theme.S.s4) {
                Text(session.title)
                    .font(Theme.F.rowTitle)
                    .foregroundStyle(Theme.C.textPrimary)
                    .lineLimit(1)
                Text(SessionDateFormat.rowDate(session.lastActivity))
                    .font(Theme.F.rowMeta)
                    .foregroundStyle(Theme.C.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            menu
        }
        .padding(.horizontal, Theme.S.rowPadding)
        .frame(height: Theme.R.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: Theme.R.button)
                .fill(Theme.C.surfaceRowSelected.opacity(selected ? 1 : (hover ? Theme.rowHoverOpacity : 0)))
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.R.button))
        .onHover { hover = $0 }
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Sync status at the bottom of the sidebar (R-38).
struct SyncStatusLine: View {
    let text: String
    var body: some View {
        HStack(spacing: Theme.S.s8) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text(text).lineLimit(1)
        }
        .font(Theme.F.rowMeta)
        .foregroundStyle(Theme.C.textSecondary)
    }
}


/// Native Menu content reused in the fixture component preview; actions are unchanged.
struct SessionActionsContent: View {
    var onRename: () -> Void = {}
    var onReveal: () -> Void = {}
    var onDelete: () -> Void = {}
    var body: some View {
        Group {
            Button("Rename…", action: onRename)
            Button("Show in journal", action: onReveal)
            Divider()
            Button("Delete…", role: .destructive, action: onDelete)
        }
    }
}
