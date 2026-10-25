# Передача LINGO-01

Статус: **P-04 реализован, ожидается H-2** (разрешения и 15 живых фраз), затем сравнение движков и завершение P-04 · Обновлено: 2026-10-25 · Ветка: `feat/lingo-01` · Commit: см. `git log -1`
Цель и границы: [intent.md](intent.md), требования: [spec.md](spec.md), шаги: [plan.md](plan.md).

## Сделано
- 2026-10-25: брейншторм с владельцем (Q1–Q26), созданы документы SDLC:
  - intent, spec, plan;
  - ADR-0001;
  - evals/README;
  - DESIGN.md (токены с макета);
  - CLAUDE.md, README;
  - executor-prompt;
  - owner-brief, pdf-patterns.

  Код не писался.
- 2026-10-25: владелец перенёс этап A на iPhone Air: «хочу на эир а потом адаптируем под айфон 11 если что» (Q25).
  Кабеля Lightning нет (Q26). Обновлены intent (устройства, ограничения, Q25–Q26, A-9), spec (раздел 4), plan (H-0, P-00, P-05, риски), ADR-0001 (кандидаты для 12 ГБ, встроенная модель Apple как дополнительный кандидат), CLAUDE.md, README, executor-prompt.
- 2026-10-25: владелец изменил порядок: «давай всё-таки начнём с Mac, а потом уже будем адаптировать под нужный iPhone» (Q27).
  LINGO-01 — только MVP для Mac (plan v2: P-00…P-12, H-0…H-5). iPhone, SideStore, F-проверки, локальная модель — LINGO-02.
  Обновлены intent v2, spec v2 (раздел 4 — черновик для LINGO-02, AC-08/AC-14/AC-16), plan v2, ADR, CLAUDE.md, README, evals, executor-prompt v2.
- 2026-10-25: владелец принял комплект v2 («давай начинаем»), статусы → accepted.
- Оригинал PDF скопирован в `private/pdf-example.pdf`. Он в .gitignore: там личная переписка с именами и списком чатов.

## Среда на 2026-10-25 (до P-00)
- macOS 15.7.2 (24G325), Apple M1, 8 ГБ.
- Xcode 26.3 (17C529), `xcode-select` → `/Applications/Xcode.app/Contents/Developer`.
- Свободно ≈14 ГБ.
- Установлены ffmpeg и Homebrew. `gh` авторизован как itmax04.
- Для LINGO-02: iPhone Air (iPhone18,4), iOS 27.0, сопряжён с Mac по USB-C, «Режим разработчика» выключен, SideStore не установлен (`devicectl`, 2026-10-25).
- В системе нет poppler, поэтому PDF рендерился через PDFKit (Swift-скрипт в scratchpad). Для работы это не нужно.

## P-00. Обследование и baseline (2026-10-25)
**Git:** ветка `feat/lingo-01`, `fade7c6`, дерево чистое, совпадает с handoff (расхождений нет).

**Среда (команды выполнены 2026-10-25):**
- `xcodebuild -version` → Xcode 26.3, Build 17C529; iOS SDK 26.2 (`xcrun --sdk iphoneos --show-sdk-version`).
- `swift --version` → Apple Swift 6.2.4 (swiftlang-6.2.4.1.4), target arm64-apple-macosx15.0.
- macOS 15.7.2 (24G325), Apple M1, 8 ГБ. `df -h /` → свободно **12 ГиБ** (меньше ≈14 ГБ из intent).
- ffmpeg, gh, brew есть; XcodeGen не установлен (нужен только в LINGO-02); Python 3.12.3.
- Подпись: в связке ключей есть самоподписанное удостоверение «InterviewCopilot» (`security find-identity -p codesigning`:
  `CSSMERR_TP_NOT_TRUSTED` — для локальной подписи это нормально, IC подписывается им же). Решение по сертификату — H-0.
- Модели whisper уже лежат у Interview Copilot (`~/Library/Application Support/InterviewCopilot/models/`):
  `ggml-large-v3-turbo-q5_0.bin` (574 041 195 Б), `ggml-small-q5_1.bin`, `ggml-medium-q5_0.bin`.

**whisper.cpp** (GitHub API `repos/ggml-org/whisper.cpp/releases`, 2026-10-25):
- последний тег `v1.9.5` (2026-10-06) без файлов; XCFramework — в сборочном релизе **`b5454`** (2026-10-06):
  `whisper-b5454-xcframework.zip`, 65 816 082 Б, SHA256 `e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b`.
  Та же версия, что в IC (`Package.swift` IC, коммит `cf0e764`).

**Groq** (https://console.groq.com/docs/rate-limits, https://console.groq.com/docs/models, https://console.groq.com/docs/billing-faqs — прочитано 2026-10-25):
- Free Plan, чат-модели: `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b` (preview) — у каждой 30 RPM, 1K RPD, 8K TPM, 200K TPD.
  `llama-3.1-8b-instant`, `llama-3.3-70b-versatile`, `minimaxai/minimax-m2.7`, `meta-models/muse-spark-open` помечены Enterprise и в таблице Free нет.
- Лимиты — на **организацию** («Rate limits apply at the organization level»), таблица задаёт их отдельно для каждой модели. Подтверждает A-4.
- Карта: прямо не сказано «без карты», способ оплаты упоминается только для перехода на Developer tier.
- 429: заголовок `retry-after` (секунды), плюс `x-ratelimit-*` (RPD/TPM). Используется в R-29.
- Точный список моделей — `GET https://api.groq.com/openai/v1/models` после H-1 (без ключа — 401).

**Mistral** (https://mistral.ai/pricing, https://docs.mistral.ai/getting-started/quickstarts/studio/activate-and-generate-api-key,
https://docs.mistral.ai/getting-started/quickstarts/developer/first-api-request — прочитано 2026-10-25):
- «Free mode: API access is enabled by default with no credit card required. Usage and rate limits apply.» Base URL `https://api.mistral.ai/v1`, `/chat/completions`.
- Числовые лимиты Free mode **не найдены**: страницы тарифов (`/deployment/ai-studio/tier/`, `/deployment/laplateforme/tier/`, статья help center) отдают 404.
  По памяти не восстанавливаются; цепочка реагирует на 429/`retry-after` динамически, поэтому для реализации числа не нужны.
  Если владелец добавит ключ Mistral в H-1, лимиты видны в его консоли.

**OpenRouter** (https://openrouter.ai/docs/api-reference/limits, https://openrouter.ai/docs/faq, `GET https://openrouter.ai/api/v1/models` — 2026-10-25):
- `:free`: 20 RPM; 50 запросов в день, если куплено < 10 кредитов (1000 — если ≥ 10, это платно, не используем). Карта для `:free` прямо не требуется.
- Base URL `https://openrouter.ai/api/v1`, OpenAI-совместимый. По умолчанию запросы не логируются.
- В каталоге 467 моделей, 17 `:free`, среди чатовых: `google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`,
  `nvidia/nemotron-3-super-120b-a12b:free`, `nvidia/nemotron-3-ultra-550b-a55b:free`, `thinkingmachines/inkling:free` и др.

**Вывод для плана:** основа цепочки — 2–3 модели Groq (gpt-oss-120b, qwen3.8-27b, gpt-oss-20b), запасные — Mistral Free и OpenRouter `:free`.
Бюджет 1K запросов в день на модель на организацию учитывается в evals (P-05): прогон `dialog` ≈ 80–160 запросов.

## P-01. Каркас, тема, окно (2026-10-25)
**Сделано:**
- `Package.swift` (Swift 6.2 tools): `LingoCore` (macOS 15 / iOS 17), `LingoMac` (продукт `Lingo`), `lingo-eval`, `LingoCoreTests`. Внешних зависимостей нет.
- `LingoCore/Model`: `Lang`, `SessionSettings` (режимы, исправления, кто начинает; без умолчаний роли/уровня — A-8; `canStart` по A-3), `Session`,
  `ChatMessage`, `ReplySegment`, `Fix`, `Phrase`, `VoiceState`; `Logging/Log.swift` (R-49, subsystem `com.itmax04.lingo`).
- `LingoMac/Design/Theme.swift` — все токены DESIGN.md §1–§4, §6. Окно из трёх колонок на фикстурах макета (`Fixtures.swift`):
  сайдбар, шапка с плашкой источника, лента с пузырями (70% ширины, ✓/✓✓, метка языка), голосовая панель «Слушаю» с волной,
  поле ввода (Enter — отправить, ⇧Enter — перенос), подсказки. Сворачивание подсказок при ширине < 1280 (R-40). «Уменьшить движение» — статичная полоса.
- Иконка приложения рисуется из токенов (`--export-iconset`), снимок окна — `Lingo --ui-snapshot <png>`.
- Скрипты: `scripts/build-app.sh` (сборка во временной папке вне iCloud, подпись A-5), `scripts/check-core-ios.sh`, `scripts/secret-scan.sh`,
  `scripts/ensure-build-dir.sh`.

**Проверки (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, 4 теста (`SessionSettingsTests`).
- `scripts/build-app.sh` — PASS: `dist/Lingo.app`, `codesign -dvvv` → `Identifier=com.itmax04.lingo.mac`, `Authority=InterviewCopilot`.
- `scripts/check-core-ios.sh` — PASS: объекты `LingoCore` с `LC_BUILD_VERSION platform 2` (iOS), minos 17.0, SDK 26.2.
  Отрицательная проверка: `import AppKit` в ядре → FAIL (как и должно).
- `scripts/secret-scan.sh` — 0 findings. Отрицательная проверка синтетическими значениями (Groq, Mistral, email) → 3 findings, значения замаскированы.
- AC-11 (часть): [evidence/ui-p01.png](evidence/ui-p01.png) — макет и настоящее окно `dist/Lingo.app` (снимок `screencapture -l`) рядом.
- Контраст (DESIGN.md §8, WCAG): `text.primary` 13,8–18,2:1, `text.secondary` 6,5–8,6:1 на всех фонах колонок, карточек и пузырей — PASS (≥ 4,5).
  Справочно: `text.tertiary` 4,0–5,3:1 (плейсхолдер, иконки), `text.metaOnAccent` на `bubble.user` 4,2:1 (время 11 pt) — ниже 4,5, но эти токены сняты с макета и §8 их не нормирует.

## H-0. Сертификат подписи (2026-10-25)
Владелец выбрал вариант 1 — оставить существующий сертификат «InterviewCopilot» (ответ «оставляй», передан сессией-координатором).
Проверено: `codesign -dvvv dist/Lingo.app` → `Authority=InterviewCopilot`. «Lingo Dev» не создаётся; `build-app.sh` по-прежнему ищет его первым.

## P-02. Журнал и синхронизация, ядро (2026-10-25)
**Сделано** (`Sources/LingoCore/Journal/`):
- `Event` (R-35: v, id-ULID, device, seq, lamport, ts UTC с мс, type, session, payload; неизвестные поля — в `extra`, неизвестные типы сохраняются),
  `JSONValue`, `ULID`, `Payloads` (типизированные payload всех 13 типов).
- `JournalWriter` — дописывание в `journal-<yyyy-mm>.jsonl` + `synchronize()` (fsync); оборванная строка закрывается переводом строки (R-39).
  `JournalReader` — пропуск оборванной последней строки и повреждённых строк (метрика в `os_log`), флаг старшей схемы.
- `Merger` → `HistoryState`: объединение по `id`, порядок сообщений (`ts`, `device`, `seq`), LWW (`lamport`, затем `device`) для названия,
  настроек, удаления-надгробия, завершения/продолжения, краткого содержания, правок и «прервано», ★ словаря. Чистая функция множества событий.
- `JournalStore` (actor) — свой журнал в `Application Support` (источник истины, R-34), кэш чужих журналов, индекс при старте,
  `seq`/`lamport` продолжаются после перезапуска, ✓✓ по отметке `pushedSeq`, «только чтение» при старшей схеме.
- `SyncFolder` — структура `Lingo/v1/devices/<deviceId>/` + `device.json`, запись только в свою папку, чтение чужих через `NSFileCoordinator`,
  `startDownloadingUbiquitousItem` для недогруженных файлов (в т. ч. заглушки `.icloud`), security-scoped bookmark. `SyncScheduler` (R-38):
  запуск, активация, раз в 60 с, конец сессии, кнопка; склейка запросов; синхронизация не блокирует разговор.
- `lingo-eval sync-write | sync-now | sync-view` — второе «устройство» для S-19. `scripts/sync-check.py` — дубли, «чужой писатель», число сообщений,
  потери и порядок в локальных базах.

**Проверки (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **19 тестов** в 5 наборах: кодек событий и неизвестные поля; оборванная строка, повреждённая строка,
  старшая схема; дописывание после обрыва; порядок при равных `ts`; 50 перестановок с дублями; LWW по `lamport` и `device`; правки, «прервано»,
  надгробие, ★/снятие ★, неизвестный тип; свойство коммутативности и идемпотентности (30 случайных пар журналов); **2 писателя × 25 сообщений**
  через `SyncFolder` (50 сообщений, одинаковый порядок, без дублей, ✓✓); S-20 (папки нет → «Папка синхронизации недоступна — выбрать снова»,
  история цела после перезапуска); старшая схема у другого устройства → `readOnly`; продолжение `seq`/`lamport`.
- S-19 через CLI на временной папке: `lingo-eval sync-write … --offline` ×2 по 25, `sync-now` ×3, `scripts/sync-check.py … --expect 50` →
  `RESULT: PASS (0 потерь, 0 дублей)`, у обеих локальных баз `lost=0 order_mismatch_sessions=0 dup=0`. Отрицательная проверка (дубль строки) → FAIL.
- `scripts/check-core-ios.sh` — PASS (15 объектов, platform 2). `scripts/secret-scan.sh` — 0 findings.
- Реальная папка iCloud — в P-10 (H-3).

## P-03. Цепочка моделей (2026-10-25) — до H-1
**Сделано:**
- `LingoCore/LLM` (перенос из IC `cf0e764` с шапкой источника): `LLMTypes` (ошибка HTTP с `retry-after`), `ProviderID`/`ProviderEndpoints`
  (Groq, Mistral, OpenRouter, свой адрес; только HTTPS, http — только localhost), `SSEClient` (+ `retry-after`, вычистка ключа из ошибок),
  `OpenAICompatibleProvider`, `ProviderChain` (R-29: шаги «провайдер → модель → ключ», неограниченные ключи, 401/403 выключают ключ,
  пауза по `retry-after` или 300 с на пару «ключ + модель», таймаут первого токена 6 с, `restart` при обрыве, S-18 с «через N»),
  `KeyVerifier` (`GET /models`, только чат-модели), `LLMSettings` (ключи без значений, порядок цепочки, модели из `/models`).
- `LingoCore/Secrets/KeychainStore` — service `com.itmax04.lingo`, account = id ключа (R-48).
- `LingoCore/Dialogue`: `ReplyProtocol` + потоковый `ReplyStreamParser` (R-24: предложения `@say` отдаются на озвучку до конца строки,
  `<think>` вырезается, битые строки → `protocol_violation`), `PromptBuilder` (R-25: обёртка, данные в `<session_prompt>`, `<summary>`,
  `<transcript>`, отметка `interrupted_at`), `ContextPolicy` (R-04: N = 20, 6–40, краткое содержание каждые 10 ходов).
- `LingoCore/Settings/AppSettings` + `SettingsStore` (UserDefaults, терпимое декодирование). `Commands/CommandKind`.
- Mac: окно «Настройки Lingo» (⌘,), вкладка «Ключи и модели»: ключи по провайдерам (добавить, «Проверить», удалить, ••••последние 4,
  «недействителен»), «Получить ключ…», порядок цепочки (вкл/выкл, модель из списка `/models`, вверх/вниз, удалить, добавить шаг), таймаут 2–15 с.
  Плашка источника показывает первый доступный шаг (R-32). Служебный режим `Lingo --check-keys` (из подписанного .app).

**Проверки (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **43 теста** в 11 наборах. Новые: цепочка на mock-провайдере (101 шаг из 51 ключа в порядке
  провайдер → модель → ключ; 429 → следующий ключ; 401 → выключен только этот ключ, его шаги с другой моделью пропущены; таймаут первого токена;
  обрыв посреди ответа → `restart`; исчерпание с `retryAfter` ≈ 120 с и повторный запуск без запросов; пауза 300 с по умолчанию и по паре
  «ключ + модель»; нет ключей → S-18); провайдер (429 + `retry-after: 17`, ключ вычищен из текста ошибки; разбор SSE и usage; тело запроса
  Groq/Mistral; свой адрес только HTTPS/localhost); `KeyVerifier` (только чат-модели, 401); протокол R-24 (все теги, 5 видов битых строк,
  предложения до конца строки, `<think>` через границу кусков); `ContextPolicy`; **21 снапшот** `PromptBuilder` (3 режима × 7 сочетаний)
  + проверки правил (нет «Thomas», произношение, русский только по просьбе, один вопрос, протокол, блок `<session_prompt>` только в «Своём промпте»);
  данные помечены и `</transcript>` из реплики вырезается.
- `scripts/build-app.sh` — PASS; окно настроек проверено снимком настоящего окна. `scripts/check-core-ios.sh` — PASS. `scripts/secret-scan.sh` — 0 findings.
- `GET /models` у Groq — **NOT RUN** до H-1 (нет ключа).

**H-1 (2026-10-25).** Владелец добавил ключ Groq в «Настройки → Ключи и модели» (ответ «готово» через сессию-координатор).
`dist/Lingo.app/Contents/MacOS/Lingo --check-keys --all-models` (та же сборка, запроса Связки ключей не было):
```
Groq ключ 1 ••••<4>: Ключ работает · моделей: 4
  models: allam-2-7b, openai/gpt-oss-120b, openai/gpt-oss-20b, qwen/qwen3.8-27b
chain: on  Groq openai/gpt-oss-120b [ok]
chain: on  Groq qwen/qwen3.8-27b [ok]
chain: on  Groq openai/gpt-oss-20b [ok]
chain: on  Mistral mistral-small-latest [?]   (ключа нет)
chain: on  OpenRouter google/gemma-4-31b-it:free [?]   (ключа нет)
```
Чат-модели Groq по `GET /models` на 2026-10-25: `allam-2-7b`, `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`.
Цепочка по умолчанию совпадает со списком; `allam-2-7b` (модель для арабского) в цепочку не добавлена. Окончательный порядок — по eval `dialog` (P-05).
Ключей Mistral и OpenRouter нет: запасные шаги пропускаются, пока ключи не добавлены.

## P-04. Речь на Mac (2026-10-25) — до H-2
**Сделано** (`LingoCore/Speech`, `LingoCore/Audio`, `LingoCore/Commands`):
- `SpeechRecognizer` (кандидаты {изучаемый, ru}, `forced` — кнопка «Говорю по-русски»), `UtteranceBuffer` (≤ 60 с в памяти, R-08).
- `WhisperEngine` (перенос из IC `cf0e764`): Metal, стратегии языка `detect | dual | smallDetect`, урезанный контекст, двуязычная затравка,
  метка языка по алфавиту текста. `AppleSpeechEngine` (`SFSpeechRecognizer`, только на устройстве, параллельно по кандидатам).
- `ModelStore`: каталог whisper с SHA256 из Hugging Face (LFS oid, проверено 2026-10-25: large-v3-turbo-q5_0 `3942…7e2`, small-q5_1 `ae85…1bb`),
  APFS-клон из моделей IC или загрузка с HF, проверка суммы. Обе модели установлены клоном за 0,4 с, место не расходуется (D-02).
- `EnergyVAD` (перенос из IC, + запас для перебивания), `VoiceDefaults`, `TurnSegmenter` (R-10 T, R-11 G, минимум речи 0,3 с, склейка,
  запрет склейки после начала озвучки), `TurnTimeline`.
- `VoiceIO`: один `AVAudioEngine` — микрофон с voice processing (эхоподавление) и озвучка `AVSpeechSynthesizer.write` → `AVAudioPlayerNode`
  (эхоподавление видит голос помощника, позиция перебивания — по сэмплам), прогрев голоса, пауза микрофона на время прослушивания фразы (R-27).
  `Voices` (premium → enhanced → default), `SlowChunks` (R-15), `SpeechPace` (×0,75 / ×0,6). `Permissions` (микрофон, распознавание).
- `CommandDetector` (R-14…R-22): целая реплика без слов-паразитов с допуском опечаток по длине; команды с аргументом по точному началу.
- Evals: `evals/commands/{ru,de,en}.yaml` (128 фраз, 34 отрицательных = 26,6%), `evals/turn/timelines.yaml` (22 таймлайна, 29 реплик),
  `evals/audio/phrases.yaml` + `scripts/make-audio-fixtures.sh` (75 записей `say` + ffmpeg, в Git только тексты),
  `lingo-eval commands | turn | stt | stt-bench | tts-bench | chunk-debug | model-install`, `scripts/run-evals.sh`.
- Окно «Проверка распознавания» (`Lingo --stt-check part1|part2`, меню Lingo): фраза → запись в память → whisper и Apple → WER →
  «Понятно / Непонятно»; итог в `~/Library/Application Support/Lingo/evals/live-stt-<part>.json` (только тексты). Фразы — `Resources/live-phrases.json`,
  сценарий — `evals/live-script-mac.md`.

**Проверки (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **55 тестов** в 14 наборах (новые: сегментация, склейка S-05, запрет склейки после озвучки,
  шум < 0,3 с, flush, диапазоны T/G; детектор команд и опечатки; части «медленнее»; WER; метка языка по алфавиту; буфер 60 с;
  установка модели клоном и отказ при неверной сумме).
- `scripts/run-evals.sh commands` — **PASS**: 127/128 = 99,2% (≥ 95%), ложных срабатываний 1/34 = 2,9% (≤ 3%). Промах: «Wie sagt man das in deiner
  Familie, weiß ich nicht» → how_to_say (начало совпадает с командой). Три метки, поставленные сначала под детектор, исправлены на смысловые.
- `scripts/run-evals.sh turn` — **PASS**: 29 реплик, 0% обрывов, 0% ложных склеек — и по таймлайну, и через синтез звука + EnergyVAD.
  Это синтетика; на живой речи — H-4.
- `lingo-eval stt` (синтетика `say`, 75 записей), whisper large-v3-turbo q5_0:

  | Вариант | en | de | ru | смешанные авто | смешанные с кнопкой | задержка | память |
  |---|---|---|---|---|---|---|---|
  | detect, урезанный контекст (как в IC) | 4/20 | 3/20 | 0/20 | 3/15 | 3/15 | 3,9 с | 761 МБ |
  | detect, полный контекст | 20/20 | 20/20 | 20/20 | 7/15 | 5/15 | 4,2–4,5 с | 763 МБ |
  | dual@512 | 20/20 | 20/20 | 20/20 | 10/15 | 7/15 | 1,3–1,4 с | 754 МБ |
  | smallDetect@512 | 20/20 | 20/20 | 20/20 | 10/15 | 7/15 | 1,2 с | 1148 МБ |
  | **dual@512 + затравка + метка по алфавиту (выбор)** | **20/20, язык 100%** | **20/20, 100%** | **20/20, 100%** | **13/15** | **13/15** | **1,45–1,65 с** | **759 МБ** |
  | small q5_1 dual@512 + затравка | 20/20 | 18/20 | 19/20 | 5/15 | 4/15 | 0,5 с | 447 МБ |

  «Понятно» = WER ≤ 25%. Первая затравка совпадала с фразами набора (утечка, 15/15) — заменена на нейтральную; в таблице — честный результат.
- `lingo-eval tts-bench`: установлены только голоса качества Default (en Aaron, de Anna, ru Milena) → R-13: предложить скачать улучшенные.
  Первый синтез голосом ≈ 1,1 с, следующие 15–40 мс → прогрев голосов при старте сессии (R-14 ≤ 0,3 с). Маркеров слов эти голоса не дают.
- `scripts/build-app.sh` — PASS (whisper.framework в бандле, `codesign --verify --deep --strict` OK, 19 МБ). `--check-keys` после пересборки
  прочитал ключ **без** запроса Связки ключей. `scripts/check-core-ios.sh` — PASS (ядро с whisper и звуком). `scripts/secret-scan.sh` — 0 findings.
- Apple Speech, живые фразы, перебивание — **NOT RUN** до H-2 / H-4 (нет разрешений у процесса и живой речи).

## Решения исполнителя
- **D-01 (P-00, R-30).** Числовые лимиты Mistral Free не найдены (страницы 404). Не блокирует: R-29 обрабатывает 429 динамически. Значения не придумываются.
- **D-02 (P-00, ADR-0001 п. 6, диск).** Свободно 12 ГиБ. Модели whisper для Lingo берутся APFS-клоном (`cp -c`) из папки моделей IC
  с проверкой SHA256 по сумме Hugging Face — место на диске не расходуется. Если файла нет — загрузка с Hugging Face с проверкой SHA256.
- **D-03 (P-01, A-6).** В Xcode 26.3 не установлен компонент платформы iOS 26.2 (`xcodebuild … generic/platform=iOS` → «iOS 26.2 is not installed»),
  SDK `iphoneos` при этом есть. Скачивать платформу (несколько ГБ при 12 ГиБ свободных) не стал: `check-core-ios.sh` собирает цель `LingoCore`
  через `swift build --triple arm64-apple-ios17.0 --sdk <iPhoneOS.sdk>` и проверяет платформу объектов. Если платформу установят, скрипт дополнительно
  запускает xcodebuild. Для LINGO-02 (сборка IPA) платформу придётся установить: Xcode → Settings → Components.
- **D-04 (P-01, AC-14).** Репозиторий лежит на «Рабочем столе», который синхронизируется с iCloud Drive: File Provider менял файлы во время сборки
  («modified during the build»). `.build` — симлинк в `~/Library/Caches/com.itmax04.lingo/build` (`scripts/ensure-build-dir.sh`, вызывается из build-app.sh).
- **D-05 (P-01, DESIGN.md).** Добавлены токены с пометкой «добавлено, P-01»: `size.waveBar` 3 pt / `space.waveGap` 4 pt, `size.statusDot` 12 pt.
  Внутреннее поле дорожки сегмента — 4 pt (на макете ≈ 1,5 pt, но DESIGN.md §3 разрешает только шаг 4). Строки сессий шире остальных элементов
  колонки на 8 pt с каждой стороны, как на макете. Иконки робота нет в SF Symbols — нарисована фигурой (`RobotIcon`).
- **D-07 (P-02, R-37).** Время событий хранится с точностью до миллисекунды и при записи округляется — порядок не зависит от точности Double.
  При совпадении `id` с разным содержимым (не должно случаться) выбор детерминирован по (`lamport`, `device`, `seq`).
  Сессия показывается, только когда пришло её `session.created`; события без него хранятся и применятся позже.
- **D-08 (P-02, R-36).** Если выбранная папка называется «Lingo», структура `v1/…` создаётся прямо в ней, иначе — в подпапке «Lingo».
  Свой журнал копируется в папку целиком при изменении размера (один писатель на файл, файлы помесячные и небольшие).
- **D-09 (P-03, R-29).** 401 и 403 выключают ключ всегда; 400 — только если текст ошибки говорит о ключе («api key», «authentication»…).
  Иначе 400 из-за параметров запроса выключал бы рабочий ключ. Groq, Mistral и OpenRouter отвечают на неверный ключ кодом 401.
- **D-10 (P-03, R-29).** Параллельный запуск (hedge) не переносился: по R-29 он выключен по умолчанию, а задержка до 8–10 с допустима (Q3).
  Шаги на паузе по 429 пропускаются; на паузе по таймауту или сети — пробуются последними, если свежих шагов нет.
- **D-11 (P-03, R-48).** Связка ключей с недоверенным самоподписанным сертификатом спрашивает доступ после каждой пересборки (опыт IC, COPILOT-01 P-11).
  Поэтому всё, что читает ключи (проверка, `GET /models`, evals `dialog`), запускается из подписанного `dist/Lingo.app` (`--check-keys`, далее `--eval`),
  а не из `lingo-eval`. Ключи читаются не на главном потоке. После пересборки владельцу может понадобиться нажать «Разрешать всегда».
- **D-12 (P-03, DESIGN.md).** Окна настроек на макете нет: цвета, шрифты, радиусы и отступы — из DESIGN.md, элементы управления — системные
  (тёмное оформление), ширины колонок списка цепочки — технические.
- **D-13 (P-04, ADR п. 6).** Урезанный `audio_ctx` под длину звука (приём IC) на large-v3-turbo давал мусор и зацикливание; минимум 512 кадров
  сохраняет качество и в 3 раза быстрее полного контекста. Определение языка whisper на полном контексте стоит ≈ 2 с, поэтому язык выбирается
  двойным прогоном (`dual`): дешевле и без второй модели (smallDetect даёт 1,15 ГБ, AC-15 под угрозой).
- **D-14 (P-04, R-08, R-09).** Смешанная речь: двуязычная затравка `initial_prompt` (текст не пересекается с наборами evals) удерживает обе части
  фразы, без неё whisper выбрасывал или переводил часть на другом языке. Метка языка — по доле кириллицы итогового текста.
  Распознавание по кускам между паузами отключено: на синтетике паузы между частями слишком короткие, выигрыша нет.
- **D-15 (P-04, R-12, R-13).** Озвучка идёт через тот же `AVAudioEngine`, что и микрофон (`AVSpeechSynthesizer.write` → player node):
  эхоподавление voice processing получает голос помощника как опорный сигнал, а место перебивания берётся из позиции плеера
  (у стандартных голосов нет маркеров слов — пропорционально доле проигранного звука части).
- **D-16 (P-04, R-14).** «Повтори» ≤ 0,3 с: голоса прогреваются при старте сессии (первый синтез ≈ 1 с), повтор синтезируется заново (15–40 мс).
- **D-17 (Git, iCloud).** 2026-10-25 18:08 после `git rm --cached` файл `.git/index` пропал, остался `.git/index.lock` — все файлы стали «удалёнными
  + неотслеживаемыми». Причина — вероятно, File Provider iCloud («Рабочий стол» синхронизируется). Восстановлено: `mv .git/index.lock .git/index`
  (тот самый индекс, что записал git), рабочие файлы не пострадали. Перед каждым коммитом проверяется `git status`. Владельцу в отчёте —
  рекомендация исключить репозиторий из iCloud (решение владельца, путь задан в задаче). Там же: для проверки `secret-scan.sh` делался локальный
  коммит-проба с синтетическим ключом и снимался `git reset --soft HEAD~1` (не пушился, в истории ветки его нет).
- **D-06 (P-01, R-32).** На фикстуре плашка источника — «На устройстве», как на макете (для сравнения AC-11). В приложении на Mac значения по R-32:
  «Groq · <модель>» или «Нет сети» (с P-03/P-10).

## Следующий шаг
H-2 (разрешения + 15 живых фраз в окне проверки) → сравнение whisper и Apple по `live-stt-part1.json` → выбор движка в ADR → коммит P-04 → P-05.
