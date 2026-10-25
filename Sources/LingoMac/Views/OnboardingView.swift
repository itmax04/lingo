import AppKit
import LingoCore
import SwiftUI

/// Мастер первого запуска (R-45): 1) разрешения на микрофон и распознавание; 2) ключ Groq (можно пропустить — голос неактивен);
/// 3) папка синхронизации (можно пропустить).
struct OnboardingView: View {
    let services: AppServices
    let keys: KeysController
    let onDone: () -> Void
    @State private var step = 0
    @State private var mic = Permissions.microphone
    @State private var speech = Permissions.speech

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Добро пожаловать в Lingo").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
            Text("Шаг \(step + 1) из 3").font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            switch step {
            case 0:
                SettingsCard(title: "Микрофон и распознавание речи",
                             subtitle: "Lingo слушает вашу речь и распознаёт её на этом Mac. Звук не сохраняется и не уходит в сеть — в модель отправляется только текст.") {
                    status("Микрофон", mic)
                    status("Распознавание речи", speech)
                    Button("Разрешить") {
                        Task {
                            _ = await Permissions.requestMicrophone()
                            _ = await Permissions.requestSpeech()
                            mic = Permissions.microphone
                            speech = Permissions.speech
                            if mic == .granted { services.prepareVoice() }
                        }
                    }
                    if mic == .denied {
                        Text("Доступ запрещён. Включите Lingo: Системные настройки → Конфиденциальность и безопасность → Микрофон.")
                            .font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                    }
                }
            case 1:
                ProviderKeysCard(keys: keys, provider: .groq)
                Text("Без ключа голос и ответы модели неактивны; ключ можно добавить позже в Настройках.")
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            default:
                SettingsCard(title: "Папка синхронизации",
                             subtitle: "Чтобы история была общей с iPhone (LINGO-02), выберите папку «Lingo» в iCloud Drive. История всегда хранится и на этом Mac.") {
                    Text(services.model.syncFolderPath ?? "Не выбрана").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                    Button("Выбрать папку…") { services.chooseSyncFolder() }
                }
            }
            Spacer(minLength: 0)
            HStack {
                if step > 0 { Button("Назад") { step -= 1 } }
                Spacer()
                if step > 0 { Button("Пропустить") { next() } }
                Button(step == 2 ? "Готово" : "Дальше") { next() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 680, height: 520)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
    }

    func next() {
        if step < 2 { step += 1 } else {
            services.updateSettings { $0.onboardingDone = true }
            onDone()
        }
    }

    func status(_ title: String, _ s: Permissions.State) -> some View {
        HStack(spacing: Theme.S.s8) {
            Circle().fill(s == .granted ? Theme.C.statusSuccess : Theme.C.statusDanger).frame(width: Theme.S.s8, height: Theme.S.s8)
            Text("\(title): \(s == .granted ? "разрешено" : (s == .denied ? "запрещено" : "не запрошено"))")
                .font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
        }
    }
}
