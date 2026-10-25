# Lingo

Личное приложение для голосовой разговорной практики английского и немецкого. Объяснения на русском даются по просьбе.
Сначала macOS (LINGO-01), затем адаптация под iPhone (LINGO-02). Без платных сервисов.

**Статус:** документы LINGO-01 приняты 2026-10-25, реализация начинается с P-00.

## Документы
| Что | Где |
|---|---|
| Исходное ТЗ владельца | [docs/reference/owner-brief.md](docs/reference/owner-brief.md) |
| Цель, границы, решения Q1–Q27 | [docs/changes/LINGO-01/intent.md](docs/changes/LINGO-01/intent.md) |
| Требования R-, критерии AC- (и черновик проверок F- для iPhone) | [docs/changes/LINGO-01/spec.md](docs/changes/LINGO-01/spec.md) |
| Шаги P-00…P-12, точки H-0…H-5 | [docs/changes/LINGO-01/plan.md](docs/changes/LINGO-01/plan.md) |
| Стек | [docs/decisions/ADR-0001-stack.md](docs/decisions/ADR-0001-stack.md) |
| Evals | [evals/README.md](evals/README.md) |
| Дизайн | [DESIGN.md](DESIGN.md), [docs/design/lingo-mac.webp](docs/design/lingo-mac.webp) |
| Паттерны из PDF-примера | [docs/reference/pdf-patterns.md](docs/reference/pdf-patterns.md) |
| Где остановилась работа | [docs/changes/LINGO-01/handoff.md](docs/changes/LINGO-01/handoff.md) |
| Промпт исполнителя | [docs/changes/LINGO-01/executor-prompt.md](docs/changes/LINGO-01/executor-prompt.md) |

## Структура (план)
```
Package.swift            LingoCore, LingoMac, lingo-eval, LingoCoreTests
Sources/LingoCore/       Journal, LLM, Secrets, Dialogue, Commands, Speech, Metrics (LocalLLM — в LINGO-02)
Sources/LingoMac/        приложение macOS
Sources/lingo-eval/      CLI для evals
ios/                     (LINGO-02) iPhone-приложение
scripts/                 build-app.sh, check-core-ios.sh, secret-scan.sh, run-evals.sh, metrics.py, sync-check.py
evals/                   наборы и сценарии живых проверок
private/                 оригинал PDF (не в Git)
```

## Команды
Появятся по шагам plan.md. До этого их результат — NOT RUN.
