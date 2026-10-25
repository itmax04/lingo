# Передача LINGO-01

Статус: **документы на приёмке владельца** · Обновлено: 2026-10-25 · Ветка: `feat/lingo-01` · Commit: см. `git log -1`
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
- Оригинал PDF скопирован в `private/pdf-example.pdf`. Он в .gitignore: там личная переписка с именами и списком чатов.

## Среда на 2026-10-25 (до P-00)
- macOS 15.7.2 (24G325), Apple M1, 8 ГБ.
- Xcode 26.3 (17C529), `xcode-select` → `/Applications/Xcode.app/Contents/Developer`.
- Свободно ≈14 ГБ.
- Установлены ffmpeg и Homebrew. `gh` авторизован как itmax04.
- Для LINGO-02: iPhone Air (iPhone18,4), iOS 27.0, сопряжён с Mac по USB-C, «Режим разработчика» выключен, SideStore не установлен (`devicectl`, 2026-10-25).
- В системе нет poppler, поэтому PDF рендерился через PDFKit (Swift-скрипт в scratchpad). Для работы это не нужно.

## Решения исполнителя
_(пока нет)_

## Следующий шаг
Владелец читает и принимает комплект (или присылает правки). После «принимаю» статусы меняются на accepted,
и в intent.md записывается согласование. Затем — новая сессия Claude Code в `~/Desktop/1/lingo` с текстом из executor-prompt.md, начало с P-00; первая точка владельца — H-0 на P-01 (сертификат подписи).
