# Передача LINGO-01

Статус: **P-01 выполнен, ожидается H-0** (сертификат подписи), затем P-02 · Обновлено: 2026-10-25 · Ветка: `feat/lingo-01` · Commit: см. `git log -1`
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
- **D-06 (P-01, R-32).** На фикстуре плашка источника — «На устройстве», как на макете (для сравнения AC-11). В приложении на Mac значения по R-32:
  «Groq · <модель>» или «Нет сети» (с P-03/P-10).

## Следующий шаг
H-0 (сертификат подписи) → затем P-02 (журнал и синхронизация, ядро).
