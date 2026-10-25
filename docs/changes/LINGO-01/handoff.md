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
- Оригинал PDF скопирован в `private/pdf-example.pdf`. Он в .gitignore: там личная переписка с именами и списком чатов.

## Среда на 2026-10-25 (до P-00)
- macOS 15.7.2 (24G325), Apple M1, 8 ГБ.
- Xcode 26.3 (17C529), `xcode-select` → `/Applications/Xcode.app/Contents/Developer`.
- Свободно ≈14 ГБ.
- Установлены ffmpeg и Homebrew. `gh` авторизован как itmax04.
- iPhone к Mac не подключён. SideStore не установлен (Q1). Целевое устройство этапа A — iPhone Air, подключение USB-C.
- В системе нет poppler, поэтому PDF рендерился через PDFKit (Swift-скрипт в scratchpad). Для работы это не нужно.

## Решения исполнителя
_(пока нет)_

## Следующий шаг
Владелец читает и принимает комплект (или присылает правки). После «принимаю» статусы меняются на accepted,
и в intent.md записывается согласование. Затем — новая сессия Claude Code в `~/Desktop/1/lingo` с текстом из executor-prompt.md, начало с P-00 → H-0.
