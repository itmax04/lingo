# DESIGN.md — Lingo

Источник: макет владельца [docs/design/lingo-mac.webp](docs/design/lingo-mac.webp) (1774×887 px), выбор владельца Q15 от 2026-10-25.
Цвета сняты пипеткой с макета 2026-10-25 (самый частый цвет пикселей в области элемента). Размеры пересчитаны из пикселей макета в pt с коэффициентом **1,44**
(окно на макете ≈ 1730 px ≈ 1200 pt). Значений, которых здесь нет, **не придумывать**. Если чего-то не хватает, исполнитель
добавляет значение сюда с пометкой «(добавлено, P-xx, обоснование)» и показывает владельцу при приёмке.

Платформа: macOS (SwiftUI) в LINGO-01. iPhone — по отдельному дизайну владельца (LINGO-02); этот файл тогда дополняется.
Тема: **только тёмная** в v1. Светлой темы на макете нет, её значения не придумываются.

## 1. Цвета
| Токен | HEX | Где на макете |
|---|---|---|
| `bg.window` | `#121619` | Фон ленты сообщений |
| `bg.sidebar` | `#14181B` | Левая колонка |
| `bg.hints` | `#161A1E` | Правая колонка |
| `bg.titlebar` | `#1B2125` | Полоса заголовка окна |
| `surface.card` | `#1F252A` | Карточки подсказок, дорожка сегмента English/Deutsch |
| `surface.voicePanel` | `#171D22` | Голосовая панель |
| `surface.input` | `#181F21` | Поле ввода |
| `surface.bubbleAssistant` | `#242E38` | Пузырь помощника |
| `surface.rowSelected` | `#232C39` | Выбранная сессия в списке |
| `surface.control` | `#283039` | Круглая кнопка «Пауза» |
| `surface.sendButton` | `#333D47` | Круглая кнопка отправки |
| `surface.chip` | `#101719` | Плашка источника («На устройстве») |
| `border.subtle` | `#23292E` | Обводка карточек, плашки, голосовой панели и поля ввода |
| `border.divider` | `#272B2E` | Разделители колонок |
| `accent.primary` | `#1162F4` | «Новая сессия», активный сегмент |
| `bubble.user` | `#105DEB` | Пузырь пользователя |
| `avatar.userBg` | `#1B324F` | Круг аватара пользователя |
| `avatar.userIcon` | `#4075D1` | Иконка человека |
| `avatar.botBg` | `#274246` | Круг аватара помощника |
| `avatar.botIcon` | `#87EBE0` | Иконка робота |
| `voice.accent` | `#5BF2DF` | «Слушаю», волна, иконка микрофона |
| `voice.accentSoft` | `#1C433F` | Круг микрофона на панели |
| `status.danger` | `#E64542` | Кнопка «Завершить» |
| `status.success` | `#1FD67F` | Точка статуса в плашке источника |
| `text.primary` | `#FFFFFF` | Заголовки, текст пузырей, названия сессий |
| `text.secondary` | `#AAB3BF` | Подзаголовок, даты сессий, перевод фраз, «Мои сессии» |
| `text.tertiary` | `#848B97` | Плейсхолдер поля ввода, иконки в покое |
| `text.metaOnAccent` | `#AFE8FF` | Время и ✓✓ на синем пузыре |
| `icon.send` | `#E7EFF8` | Иконка «отправить» |

`text.secondary` выведен по сглаженным пикселям текста (самый светлый пиксель #C7D2E1 минус сглаживание). При приёмке он сверяется скриншотом рядом с макетом.

## 2. Типографика
Шрифт — системный SF Pro (`.system`), кириллица и латиница одним шрифтом. Размеры в pt:
| Токен | Размер / насыщенность | Где |
|---|---|---|
| `type.logo` | 30 / bold | «Lingo» |
| `type.title` | 22 / semibold | Название сессии в шапке |
| `type.subtitle` | 14 / regular, `text.secondary` | «Свободный разговор на английском» |
| `type.button` | 16 / medium | «Новая сессия» |
| `type.segment` | 14 / medium | English / Deutsch |
| `type.section` | 13 / regular, `text.secondary` | «Мои сессии», «Полезные фразы для этой темы» |
| `type.rowTitle` | 14 / regular | Название сессии в списке |
| `type.rowMeta` | 12 / regular, `text.secondary` | «Сегодня, 14:28» |
| `type.bubble` | 17 / regular | Текст сообщений |
| `type.meta` | 11 / regular | Время в пузырях, метка «провайдер · модель» |
| `type.panelTitle` | 17 / semibold | «Подсказки» |
| `type.hintPhrase` | 16 / semibold | Фраза подсказки |
| `type.hintTranslation` | 13 / regular, `text.secondary` | Перевод |
| `type.voiceState` | 16 / semibold, `voice.accent` | «Слушаю» |
| `type.caption` | 11 / regular | «Пауза», «Завершить» под кнопками |
| `type.chip` | 13 / regular | «На устройстве» |

Динамический размер шрифта на macOS не используется. Минимальный размер текста — 11 pt.

## 3. Отступы и сетка
Базовый шаг — 4 pt. Используются только значения: **4, 8, 12, 16, 20, 24, 32**.
| Токен | Значение | Где |
|---|---|---|
| `layout.sidebarWidth` | 256 pt | Левая колонка |
| `layout.hintsWidth` | 264 pt | Правая колонка (сворачивается при ширине окна < 1280, R-40) |
| `layout.headerHeight` | 72 pt | Шапка центральной колонки |
| `space.columnPadding` | 16 pt | Внутренние поля колонок |
| `space.messageGap` | 16 pt | Между сообщениями |
| `space.bubblePaddingH` / `V` | 16 / 12 pt | Поля внутри пузыря |
| `space.avatarGap` | 12 pt | Аватар ↔ пузырь |
| `space.rowPadding` | 12 pt | Строка сессии |
| `space.cardGap` | 12 pt | Между карточками подсказок |

Ширина пузыря — не больше 70% центральной колонки.

## 4. Радиусы и размеры элементов
| Токен | Значение |
|---|---|
| `radius.button` | 8 pt («Новая сессия», сегмент, строка сессии) |
| `radius.bubble` | 16 pt |
| `radius.card` | 10 pt (карточки подсказок) |
| `radius.capsule` | половина высоты (голосовая панель, поле ввода, плашка источника) |
| `size.primaryButtonHeight` | 40 pt |
| `size.segmentHeight` | 36 pt |
| `size.rowHeight` | 50 pt |
| `size.avatar` | 40 pt, круг |
| `size.voicePanelHeight` | 86 pt |
| `size.micCircle` | 50 pt |
| `size.roundButton` | 44 pt (Пауза, Завершить) |
| `size.inputHeight` | 48 pt |
| `size.sendButton` | 40 pt |
| `size.hintCardMinHeight` | 78 pt |
| `size.chipHeight` | 32 pt |
| `stroke.subtle` | 1 pt, `border.subtle` |

## 5. Компоненты
- **Строка сессии.** Иконка «пузырь» в `text.tertiary`, название `type.rowTitle`, дата `type.rowMeta`, «…» справа.
  Выбранная — фон `surface.rowSelected`. При наведении — тот же фон с прозрачностью 50%.
- **Сегмент языка.** Дорожка `surface.card`, активный сегмент `accent.primary` + `text.primary`, неактивный — `text.secondary`.
- **Пузырь пользователя.** Фон `bubble.user`, справа. Внизу справа: время + ✓/✓✓ в `text.metaOnAccent`. Справа от пузыря аватар (`avatar.userBg`/`avatar.userIcon`).
- **Пузырь помощника.** Фон `surface.bubbleAssistant`, слева, аватар-робот (`avatar.botBg`/`avatar.botIcon`). Время `text.secondary`.
  - Блок исправления `@fix` внутри пузыря: обводка `stroke.subtle`, радиус `radius.card`.
  - Русский сегмент (R-17): фон `surface.card` внутри пузыря.
  - Прерванная часть: `text.tertiary`.
- **Голосовая панель.** Капсула `surface.voicePanel` + `stroke.subtle`.
  - Слева круг `voice.accentSoft` с иконкой микрофона `voice.accent`, подпись состояния `type.voiceState`.
  - В центре волна: столбики `voice.accent`, затухающие к краям (прозрачность 100% → 30%).
  - Справа кнопки «Пауза» (`surface.control`) и «Завершить» (`status.danger`), подписи `type.caption`.
- **Поле ввода.** Капсула `surface.input` + `stroke.subtle`, иконка клавиатуры `text.tertiary`, вертикальный разделитель `border.divider`, плейсхолдер `text.tertiary`.
  Кнопка отправки — круг `surface.sendButton`, иконка `icon.send`.
- **Плашка источника.** Капсула `surface.chip` + `stroke.subtle`, точка `status.success` (или `status.danger`, если «Нет сети»), текст `type.chip`, шеврон.
- **Карточка подсказки.** `surface.card` + `stroke.subtle`, `radius.card`. Фраза `type.hintPhrase`, перевод `type.hintTranslation`, иконка динамика справа, ★ рядом с ней.
  Иконки по умолчанию `text.primary` в покое, ★ активная — `accent.primary`.

Иконки — SF Symbols, вес regular, размер по тексту строки.

## 6. Состояния
- **Фокус клавиатуры:** системное кольцо фокуса macOS (accent цвета `accent.primary`).
- **Наведение:** фон кнопок становится светлее. Отдельных цветов нет, используется `opacity(0.85)` поверх исходного.
- **Неактивно:** `opacity(0.4)` и подсказка с причиной (R-33, S-01).
- **Ошибка:** текст `status.danger` под элементом.

## 7. Движение
- Только системные анимации SwiftUI (`.default`, `.easeInOut` 0,2 с) для появления сообщений и смены состояний панели.
- Волна — по уровню звука, без декоративной анимации.
- При «Уменьшить движение» (`accessibilityReduceMotion`) волна заменяется статичной полосой уровня, переходы — без анимации.

## 8. Доступность
- Контраст `text.primary` и `text.secondary` к фонам колонок ≥ 4,5:1 (проверить на P-10, записать в handoff).
- Все кнопки-иконки имеют `accessibilityLabel` на русском.
- Команды доступны с клавиатуры: пробел (удержание — говорить), Esc (стоп), ⌥R («говорю по-русски»), ⌘N (новая сессия), ⌘, (настройки).
