import LingoCore
import SwiftUI

/// Правка расшифровки (R-09): клик по своему пузырю → исправить текст → «Сохранить» или «Ответить заново».
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
            Text("Исправить расшифровку").font(Theme.F.panelTitle).foregroundStyle(Theme.C.textPrimary)
            Text("Исправленный текст сохранится в истории (событие «правка»). «Ответить заново» пересчитает ответ помощника.")
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
                Button("Отмена", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Сохранить") { onSave(text) }.disabled(text == message.text || text.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Ответить заново") { onRegenerate(text) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 520)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
    }
}
