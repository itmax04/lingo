import LingoCore
import SwiftUI

/// Transcript edit (R-09): click your own bubble → fix the text → "Save" or "Reply again".
struct EditMessageView: View {
    let message: ChatMessage
    @State private var text: String
    let onSave: (String) -> Void
    let onRegenerate: (String) -> Void
    let onCancel: () -> Void

    init(message: ChatMessage, onSave: @escaping (String) -> Void, onRegenerate: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.message = message
        _text = State(initialValue: message.text)
        self.onSave = onSave
        self.onRegenerate = onRegenerate
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Fix the transcript").font(Theme.F.panelTitle).foregroundStyle(Theme.C.textPrimary)
            Text("The corrected text is saved in the history (an “edit” event). “Reply again” regenerates the assistant's reply.")
                .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
            TextEditor(text: $text)
                .font(Theme.F.bubble)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(Theme.S.s8)
                .background(Theme.C.surfaceInput, in: RoundedRectangle(cornerRadius: Theme.R.button))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(text) }.disabled(text == message.text || text.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Reply again") { onRegenerate(text) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 520, height: 320)
        .background(Theme.C.bgWindow)
        .modifier(InterfaceAppearance())
    }
}
