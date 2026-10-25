# ADR-0001: Стек и архитектура Lingo (LINGO-01)

Статус: **draft** (ждёт приёмки) · Дата: 2026-10-25 · Владелец: itmax04 ·
Связи: [intent](../changes/LINGO-01/intent.md), [spec](../changes/LINGO-01/spec.md), [plan](../changes/LINGO-01/plan.md)
Раздел «Итоговые решения» в конце дописывает исполнитель по результатам замеров (P-04, P-05, P-08, P-09).

## Контекст
- Два отдельных приложения: macOS (MacBook Air M1, 8 ГБ, macOS 15.7.2) и iOS (iPhone 11, A13, 4 ГБ, iOS 27.x).
  На iPhone 11 нет Apple Intelligence и Foundation Models, поэтому свою локальную модель нужно нести с собой.
- Бюджет $0: бесплатный Apple ID, установка через SideStore (подпись на 7 дней, до 3 приложений, до 10 App ID в неделю),
  бесплатные тарифы облачных моделей. Регион ЕС.
- Есть рабочий код Interview Copilot (Swift 6, SwiftPM): цепочка провайдеров, SSE, Keychain, whisper.cpp.
- Xcode 26.3 установлен. Свободно ≈14 ГБ.

## Варианты оболочки
| Вариант | Плюсы | Минусы |
|---|---|---|
| **Swift (SwiftUI) на обеих платформах + общий пакет `LingoCore`** | Нативный звук (AVAudioEngine, voice processing), Speech, AVSpeechSynthesizer, Keychain, выбор файлов; переиспользование кода IC; минимум памяти | Два UI-слоя |
| React Native / Flutter | Один UI | Звук, эхоподавление и llama.cpp всё равно нативные; больше памяти на iPhone 4 ГБ |
| Веб-приложение (PWA) | Без подписи | Нет фоновой работы, нет локальной модели нужного класса, нет надёжного доступа к папке iCloud |

## Решение
1. **Язык и UI:** Swift 6, SwiftUI. Mac — окно на SwiftUI (AppKit — точечно). iOS — SwiftUI.
2. **Структура:**
   - `Package.swift` (SwiftPM), цели:
     - `LingoCore` — логика, без UI, тестируется;
     - `LingoMac` — приложение macOS, как в IC: `.app` собирает `scripts/build-app.sh`;
     - `lingo-eval` — CLI для evals на Mac;
     - `LingoCoreTests`.
   - iOS-приложение `LingoProbe` (служебное, этап A): проект генерирует **XcodeGen** из `ios/project.yml`, `.xcodeproj` в Git не хранится.
     Зависит от `LingoCore` как от локального пакета. `scripts/build-ipa.sh` собирает `.ipa` для SideStore (`xcodebuild archive`, без подписи
     или с ad-hoc подписью, упаковка `Payload/`), SideStore переподписывает его.
3. **Bundle ID:** iOS — `com.itmax04.lingo` (тот же для будущего MVP iPhone, A-6; SideStore добавляет к нему свой суффикс команды),
   Mac — `com.itmax04.lingo.mac`.
   **Подпись Mac:** локальный самоподписанный сертификат, по умолчанию существующий «InterviewCopilot» (A-5). Тогда разрешения TCC не сбрасываются при пересборке.
4. **Модели — облако:** перенос из IC `ProviderChain`, `ProviderHealth`, `SSEClient`, `KeyVerifier`, `KeychainStore`, OpenAI-совместимые провайдеры.
   Изменения по R-29: шаги «провайдер + модель + ключ», неограниченное число ключей, выключение отдельного ключа, пауза по `retry-after`.
   Провайдеры по R-30: Groq (основной), Mistral (бесплатный тариф), OpenRouter `:free`, свой адрес.
   Убраны Gemini (ЕС), DeepSeek и Anthropic (платные), Cerebras (по данным на 2026-10, бесплатного тарифа нет).
   Модели по умолчанию выбираются в P-03 по `GET /models` и eval `dialog`. Кандидаты Groq — самые сильные бесплатные чат-модели
   в списке на дату P-03 (по сторонним данным: семейства GPT-OSS и Qwen). Лимиты Groq считаются на модель, поэтому 2–3 модели Groq
   идут в цепочке до запасных провайдеров.
5. **Модели — локально (iOS):** llama.cpp (XCFramework из релизов, `binaryTarget`, тот же подход, что в IC), формат GGUF, квантование Q4_K_M.
   Кандидаты для замеров (актуальные версии и SHA256 фиксируются в P-05 по Hugging Face):
   | Кандидат | ≈Размер Q4 | Зачем в списке |
   |---|---|---|
   | Qwen3 1.7B Instruct | 1,1 ГБ | Сильный мультиязычный при малом размере |
   | Gemma 3 1B IT | 0,8 ГБ | Самый лёгкий, запас по памяти |
   | Llama 3.2 3B Instruct | 2,0 ГБ | Лучше по качеству, на грани по памяти |
   | Gemma 3n E2B IT | ≈2 ГБ | Мультиязычность, проверить поддержку в llama.cpp |

   Если на дату P-05 есть более новые модели того же класса (до ≈2 ГБ), исполнитель добавляет их с записью здесь.
   Риск: GPU A13 относится к семейству Apple6, и часть Metal-ядер llama.cpp может требовать Apple7+. Тогда инференс идёт на CPU
   (медленнее, особенно на обработке промпта). Поэтому KV-кэш обёртки переиспользуется (R-31). Фактический бэкенд записывается в P-05.
   Риск: iOS запрещает GPU в фоне, поэтому с заблокированным экраном локальная модель работает только на CPU (F-10).
6. **Распознавание:** абстракция `SpeechRecognizer` с несколькими движками. Выбор — по замерам F-06 и AC-16.
   - iOS-кандидаты:
     - Apple `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26+; проверить `isAvailable` на iPhone 11 и локали en-US/en-GB, de-DE, ru-RU);
     - `SFSpeechRecognizer` с `requiresOnDeviceRecognition`;
     - whisper.cpp `base`/`small` multilingual (автоопределение языка, смешанная речь; память).
   - Mac-кандидаты: whisper.cpp `large-v3-turbo` q5_0 (как в IC), запасной вариант `small` q5_1; `SFSpeechRecognizer` (на macOS 15 `SpeechAnalyzer` недоступен).
   - Язык реплики: автоопределение whisper, либо для движков Apple — параллельное распознавание {изучаемый, ru} с выбором по уверенности,
     если это укладывается в память и задержку. Иначе — R-09 (кнопка).
7. **Озвучивание:** `AVSpeechSynthesizer`, голоса en, de, ru на устройстве (premium, затем enhanced, затем default). Деление ответа на сегменты по R-24.
8. **Звук и перебивание:** `AVAudioEngine` с `setVoiceProcessingEnabled(true)` на входе (эхоподавление).
   iOS: `AVAudioSession` `.playAndRecord`, режим `.voiceChat`, `allowBluetooth`, `UIBackgroundModes = audio` (Info.plist, без платного entitlement).
   Учесть: микрофон AirPods переводит звук в HFP с худшим качеством. Это влияет на F-06 и F-09, фиксируется в замерах.
   VAD — энергетический с адаптивным порогом. Если он не проходит eval `turn`, ставится Silero VAD (ONNX) с записью здесь.
9. **Хранение и синхронизация:** журналы JSON Lines (R-34…R-39), собственный код, без БД. Индекс в памяти.
   Если число событий больше 100 тыс., добавляется SQLite из системы (`libsqlite3`, без зависимости) с записью здесь.
   Доступ к папке: security-scoped bookmark; `NSFileCoordinator`; `FileManager.startDownloadingUbiquitousItem`.
   Без iCloud entitlements и CloudKit — они требуют платного аккаунта.
10. **Метрики iOS:** `task_vm_info.phys_footprint`, `os_proc_available_memory()`, `ProcessInfo.thermalState`, MetricKit (`MXAppExitMetric`).
11. **Зависимости (разрешённый список):**
    - Yams — если нужен YAML для evals;
    - llama.cpp XCFramework;
    - whisper.cpp XCFramework;
    - XcodeGen (Homebrew, только сборка);
    - Silero VAD (ONNX) — только если выполнено условие п. 8.

    Всё остальное — запись в этом ADR и пометка «требует подтверждения владельца» в handoff.

## Последствия
- Mac и будущий iPhone-MVP используют одно ядро. UI iPhone (LINGO-02) добавляется без переделки логики и формата истории.
- Без платного аккаунта нет CloudKit и push. Синхронизация — по опросу папки, не мгновенно (R-38).
- Модели скачиваются при первом использовании. IPA остаётся маленькой, SideStore ставит её быстрее.
- Диск Mac: модели-кандидаты (≈6 ГБ) удаляются после выбора. Оставляется только выбранная whisper-модель Mac.

## Итоговые решения (заполняет исполнитель)
- Распознавание iOS: _(P-04/P-08)_
- Распознавание Mac: _(P-12)_
- Локальная модель iOS и бэкенд (Metal или CPU): _(P-05/P-08)_
- Цепочка по умолчанию (модели Groq и запасные): _(P-03/P-07)_
- VAD: _(P-04)_
