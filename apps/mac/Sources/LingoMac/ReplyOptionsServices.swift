import AppKit
import LingoCore

/// Reply options (LINGO-09 MR-49…MR-54): the switch, the block under the anchor, reveal, ▶ ★ Insert and refresh.
extension AppServices {
    /// The chip and ⌘⇧R. It changes only what the next request asks for; the running reply is not cut (MR-49).
    func toggleReplyOptions() {
        guard model.replyOptionsOffered || model.replyOptionsOn else { return }
        updateSettings { $0.replyOptions.toggle() }
    }

    func toggleReplyCollapsed() { updateSettings { $0.replyOptionsCollapsed.toggle() } }

    /// Reveals option `index` of the anchor (MR-52) and records it (MR-54). A second activation changes nothing.
    func revealReply(_ index: Int) {
        guard let anchor = model.replyAnchor, index >= 0, index < model.replyOptionList(for: anchor).count else { return }
        var state = model.replyBlocks[anchor.id] ?? AppModel.ReplyBlockState()
        guard state.revealed.insert(index).inserted else { return }
        model.replyBlocks[anchor.id] = state
        let engine = engine, sid = anchor.session, mid = anchor.id
        Task { await engine.recordReplyRevealed(session: sid, message: mid, index: index) }
    }

    func revealAllReplies() {
        guard let anchor = model.replyAnchor else { return }
        for i in model.replyOptionList(for: anchor).indices { revealReply(i) }
    }

    func replyPhrase(_ o: ReplyOption) -> Phrase { Phrase(lang: o.lang, text: o.text, translation: o.translation, source: .hint) }

    /// ▶ speaks the phrase through the playback path without the microphone, at the pace of Settings (Slow included).
    func playReply(_ o: ReplyOption) {
        guard ![.speaking, .recording].contains(model.voiceState) else { return }
        playPhrase(replyPhrase(o), slow: model.slowPace)
    }

    func starReply(_ o: ReplyOption) { toggleStar(replyPhrase(o)) }

    /// "Insert": the text goes into the message field; it is never sent automatically (MR-52).
    func insertReply(_ o: ReplyOption) {
        let d = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        model.draft = d.isEmpty ? o.text : d + " " + o.text
    }

    /// Whether the refresh button works (MR-53): not while a turn runs, offline or without a key, and at most twice per anchor.
    var canRefreshReplies: Bool {
        guard let a = model.replyAnchor else { return false }
        let s = model.replyBlocks[a.id] ?? AppModel.ReplyBlockState()
        return !s.refreshing && s.refreshes < ReplyOptions.maxRefreshes && model.online && !model.thinking
            && model.streaming == nil && model.voiceState != .thinking
    }

    /// One request per press, at most two per anchor; a failure shows explicit text (MR-53).
    func refreshReplies() {
        guard canRefreshReplies, let anchor = model.replyAnchor else { return }
        var state = model.replyBlocks[anchor.id] ?? AppModel.ReplyBlockState()
        let shown = model.replyOptionList(for: anchor)
        state.refreshing = true
        state.error = nil
        model.replyBlocks[anchor.id] = state
        let engine = engine, sid = anchor.session, mid = anchor.id
        Task {
            var result: Result<[ReplyOption], Error>
            do { result = .success(try await engine.refreshReplyOptions(session: sid, shown: shown)) } catch { result = .failure(error) }
            var s = model.replyBlocks[mid] ?? AppModel.ReplyBlockState()
            s.refreshing = false
            switch result {
            case .success(let options):
                s.options = options; s.refreshes += 1; s.revealed = []
            case .failure(let e):
                if case ReplyOptionsError.unavailable(let r) = e { s.error = String(localized: "Could not refresh the options: \(r)") }
                else if e is ReplyOptionsError { s.error = String(localized: "The model gave no options. Try again.") }
                else { s.error = String(localized: "Could not refresh the options: \(e.localizedDescription)") }
            }
            model.replyBlocks[mid] = s
        }
    }
}
