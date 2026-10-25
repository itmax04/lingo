# Lingo

Личное приложение для голосовой разговорной практики английского и немецкого. Объяснения на русском даются по просьбе.
macOS + iPhone 11, без платных сервисов.

**Статус:** документы LINGO-01 ждут приёмки владельцем. Кода пока нет.

## Документы
| Что | Где |
|---|---|
| Исходное ТЗ владельца | [docs/reference/owner-brief.md](docs/reference/owner-brief.md) |
| Цель, границы, решения Q1–Q24 | [docs/changes/LINGO-01/intent.md](docs/changes/LINGO-01/intent.md) |
| Требования R-, проверки F-, критерии AC- | [docs/changes/LINGO-01/spec.md](docs/changes/LINGO-01/spec.md) |
| Шаги P-00…P-17, точки H, ворота G-1 | [docs/changes/LINGO-01/plan.md](docs/changes/LINGO-01/plan.md) |
| Стек | [docs/decisions/ADR-0001-stack.md](docs/decisions/ADR-0001-stack.md) |
| Evals | [evals/README.md](evals/README.md) |
| Дизайн | [DESIGN.md](DESIGN.md), [docs/design/lingo-mac.webp](docs/design/lingo-mac.webp) |
| Паттерны из PDF-примера | [docs/reference/pdf-patterns.md](docs/reference/pdf-patterns.md) |
| Где остановилась работа | [docs/changes/LINGO-01/handoff.md](docs/changes/LINGO-01/handoff.md) |
| Промпт исполнителя | [docs/changes/LINGO-01/executor-prompt.md](docs/changes/LINGO-01/executor-prompt.md) |

## Структура (план)
```
Package.swift            LingoCore, LingoMac, lingo-eval, LingoCoreTests
Sources/LingoCore/       Journal, LLM, Secrets, Dialogue, Commands, Speech, LocalLLM, Metrics
Sources/LingoMac/        приложение macOS
Sources/lingo-eval/      CLI для evals
ios/project.yml          XcodeGen: LingoProbe (служебное приложение этапа A)
scripts/                 build-app.sh, build-ipa.sh, secret-scan.sh, run-evals.sh, metrics.py, sync-check.py
evals/                   наборы и сценарии живых проверок
private/                 оригинал PDF (не в Git)
```

## Команды
Появятся по шагам plan.md. До этого их результат — NOT RUN.
