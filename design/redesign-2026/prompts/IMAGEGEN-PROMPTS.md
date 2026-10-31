# Lingo redesign — ImageGen prompts

Version 1 · 2026-10-27 · For ChatGPT's built-in image generation (owner's subscription, no paid API).
Companion of the redesign task (change LINGO-07). Prompts are in English (image models follow English best);
every on-screen label is given **verbatim in Russian** in «» quotes — it is the real UI text of the app (language data).

---

## 0. How to use

1. **Order:** Phase 1 (three direction boards, dark + light) → the owner picks one direction → Phase 2 screens in that direction → Phase 3 teacher features → Phase 4 design system, mark and icon → Phase 5 architecture illustrations.
2. **One chat per direction.** Start the chat with the matching **style block** (§2) as the first message, then send screen prompts one by one. From the second image on, attach the approved board and say "same style as the attached image".
3. **Sizes:** Mac/desktop/iPad landscape → **1536×1024**; phone and portrait → **1024×1536**; sheets → 1536×1024; icon → 1024×1024.
4. **Text accuracy:** keep each prompt's visible text to the listed strings; if Cyrillic comes out garbled, regenerate with the fix prompt §7.1. Never accept invented labels.
5. **Save** every accepted image as `design/redesign-2026/screens/<area>-<screen>-<state>-<theme>-<size>.png` (e.g. `mac-conversation-speaking-dark-1536x1024.png`) and copy the exact prompt into `design/redesign-2026/prompts/used/<same name>.md`.
6. **Images are references, not assets:** the implementation rebuilds them in SwiftUI / HTML with DESIGN.md v2 tokens.

## 1. Owner decisions (brainstorm 2026-10-27)
| # | Decision |
|---|---|
| R-01 | Dark **and** light theme, following the system |
| R-02 | Three directions to compare: **A Quiet** (calm minimalism), **B Warm** (warm and friendly), **C Premium** (strict premium) |
| R-03 | During a session the centre is the **conversation text + a voice waveform** |
| R-04 | Nothing from the current design is kept — clean slate |
| R-05 | The assistant is an **abstract Lingo mark** that "breathes" while speaking (no robot, no human avatar) |
| R-06 | Phone navigation: **bottom tabs** «Сегодня», «Разговоры», «Словарь», «Прогресс» |
| R-07 | The app opens on **«Сегодня»**: day plan 4 × 30 min, warm-up cards, «Продолжить», streak |
| R-08 | German and English each get their **own accent colour** (no flags) |
| R-09 | Corrections are highlighted **inside the learner's own bubble** (wrong part struck/underlined, correct form next to it; tap → short rule, «В словарь») |
| R-10 | Font: system **SF Pro** (Cyrillic + Latin) |
| R-11 | Prompt sets: directions + key screens, teacher features, design system + icon, architecture illustrations |
| R-12 | Never show pronunciation scores or accent ratings anywhere |

## 2. Building blocks (paste into prompts)

### 2.1 BASE (append to every UI prompt)
```
High-fidelity UI design mockup, flat front view, pixel-crisp, realistic production app (not a concept-art poster).
Typography: SF Pro (Apple system font), crisp and fully legible Cyrillic and Latin text, correct Russian spelling.
Only the text given in «» quotes may appear, exactly as written; no lorem ipsum, no extra labels, no watermarks, no real brand logos.
Consistent 4-pt spacing grid, generous whitespace, clear visual hierarchy, accessible contrast (WCAG AA, 4.5:1 for body text).
German content uses the German accent colour, English content the English accent colour (see style). No country flags.
No pronunciation scores, no accent meters, no star ratings of speech.
```

### 2.2 FRAMES
- **MAC:** `A macOS desktop app window (traffic-light buttons top-left, no menu bar, no desktop wallpaper), 1280×800 points, shown alone on a neutral background matching the theme.`
- **PHONE:** `An iPhone screen 393×852 points shown edge-to-edge as a flat screenshot (status bar with 9:41, home indicator, no device frame, no hand).`
- **IPAD:** `An iPad landscape screen 1194×834 points as a flat screenshot, no device frame.`
- **WEB:** `A browser window (minimal Safari-like toolbar with the address "lingo.workers.dev") 1440×900, flat screenshot.`

### 2.3 STYLE blocks (first message of each direction chat)
**A — Quiet (calm minimalism)**
```
Visual direction "Quiet": calm, minimal, focused on reading and listening, in the spirit of Apple's own apps and ChatGPT voice mode.
Dark theme: soft graphite background (#111315-ish), slightly lighter panels, hairline dividers, near-white text, muted grey secondary text.
Light theme: warm paper white (#F7F6F3-ish), white panels, light grey hairlines, near-black text.
Accents: German = warm amber (#E8A33D-ish), English = calm teal (#2BB3A3-ish); used sparingly (active tab, waveform, language badge, primary button).
Shapes: radii 12–16, almost no shadows (one very soft elevation for floating panels), thin 1.5-px line icons.
Waveform: a single thin flowing line in the session's language accent.
Lingo mark: a simple rounded geometric glyph (two overlapping speech-wave arcs forming an abstract "L"), monochrome with the accent tint.
```
**B — Warm (warm and friendly)**
```
Visual direction "Warm": friendly, encouraging, adult (not childish), in the spirit of Praktika and Speak.
Light theme: warm cream background (#FBF6EF-ish), soft tinted surfaces (peach, sand), dark brown-grey text.
Dark theme: deep warm aubergine-brown (#1C1618-ish), soft tinted surfaces, warm off-white text.
Accents: German = coral/terracotta (#E46F4E-ish), English = periwinkle blue (#6E7FE8-ish).
Shapes: large radii 20–24, pill buttons, soft diffuse shadows, rounded duotone icons.
Waveform: chunky rounded bars with a soft gradient of the language accent.
Lingo mark: a soft organic blob made of two speech-bubble curves, gentle gradient in the language accent.
```
**C — Premium (strict premium)**
```
Visual direction "Premium": precise, quiet luxury, in the spirit of Linear and Arc.
Dark theme: near-black (#0A0B0D-ish) with frosted-glass panels (subtle blur, 1-px light hairline borders), a faint glow behind the active element.
Light theme: crisp white with cool steel-grey hairlines and very subtle glass panels.
Accents: German = copper (#D08A5A-ish) glow, English = ice blue (#7CC4FF-ish) glow; never more than one glowing element per screen.
Typography: SF Pro with tight tracking for titles, small-caps labels for metadata; thin precise line icons.
Shapes: radii 10–14, hairlines instead of fills, monochrome surfaces.
Waveform: a fine luminous line with a soft glow.
Lingo mark: a precise monoline emblem (an open circle with a wave crossing it), glowing faintly in the accent.
```

### 2.4 CONTENT (sample conversation used across screens)
German session «У врача · Немецкий · B1»:
- assistant: «Guten Morgen! Was führt Sie heute zu mir?»
- learner: «Ich habe seit zwei Tage Kopfschmerzen.» — correction inside the learner bubble: «Tage» struck, «Tagen» next to it
- assistant: «Das tut mir leid. Haben Sie auch Fieber?»
- hint card: «Ich habe Kopfschmerzen.» — «У меня болит голова.»

English session «IELTS Part 2 · Английский · B2»:
- assistant: «Describe a place you like to visit. You have one minute to prepare.»
- learner: «I like to visit the old harbour in Hamburg, because it is very calm in the morning.»

---

## 3. Phase 1 — direction boards (per direction: dark + light)

### 3.1 Direction board (send twice: dark, then light)
```
{STYLE block A|B|C}. Create a style board (1536×1024) for "Lingo", a personal voice tutor for spoken English and German.
Show on one canvas, neatly arranged: (1) the PHONE «Сегодня» screen, (2) the PHONE conversation screen while the assistant is speaking,
(3) a small MAC window with the conversation, (4) a strip of the colour palette with the German and English accents,
(5) the Lingo mark, (6) buttons, a language badge «DE» / «EN», a hint card and the correction highlight.
Theme: {dark|light}. Visible text only: «Сегодня», «Немецкий · 30 мин», «Английский · 30 мин», «Продолжить», «Слушаю», «Говорю»,
«Guten Morgen! Was führt Sie heute zu mir?», «Ich habe seit zwei Tage Kopfschmerzen.», «Tagen», «Ich habe Kopfschmerzen.», «У меня болит голова.».
{BASE}
```

---

## 4. Phase 2 — key screens (in the chosen direction; each in dark and light)

### 4.1 Phone
**P1 «Сегодня» (home)**
```
Same style as the attached board. {PHONE}. Theme {dark|light}. The «Сегодня» home screen.
Top: greeting «Доброе утро», small streak chip «Серия: 12 дней».
A day-plan block «План на день · 4 × 30 мин» with four session cards in a 2×2 grid:
«Немецкий · У врача» (done, check mark), «Английский · IELTS Part 2» (next, highlighted), «Немецкий · Свободный разговор», «Английский · Работа: собеседование»;
each card shows «30 мин» and the language accent.
A warm-up card «Разминка · 6 карточек · 3 мин» with a primary button «Начать».
A large primary button «Продолжить разговор».
Bottom tab bar: «Сегодня» (active), «Разговоры», «Словарь», «Прогресс».
{BASE}
```
**P2 Conversation — assistant speaking**
```
Same style. {PHONE}. Theme {dark|light}. Conversation screen of the German session.
Header: back chevron, title «У врача», subtitle «Немецкий · B1», a small source chip «Groq · 120b», a menu icon.
Feed: the Lingo mark beside assistant messages; messages from §2.4 (German): assistant «Guten Morgen! Was führt Sie heute zu mir?»,
learner bubble «Ich habe seit zwei Tage Kopfschmerzen.» with «Tage» struck through and «Tagen» highlighted next to it,
assistant «Das tut mir leid. Haben Sie auch Fieber?» (currently being spoken: the spoken part normal, the rest slightly dimmed).
Bottom voice panel (thumb-reachable): large round microphone button (64 pt), state label «Говорю», a flowing waveform in the German accent,
small round buttons «Пауза» and «Завершить», a toggle chip «По-русски» and «Медленно». No tab bar during a session.
{BASE}
```
**P3 Conversation — listening / recording / thinking / paused / error** (one image each, same layout as P2)
```
Same style and layout as the previous image. Change only the voice panel state:
(a) «Слушаю» — waveform reacting to the learner's voice, microphone ring pulsing;
(b) «Запись» — push-to-talk active, a timer «0:04»;
(c) «Думаю…» — the learner's last bubble just added, a subtle typing indicator next to the Lingo mark;
(d) «Пауза» — waveform flat and dimmed, button «Продолжить»;
(e) error — banner «Нет сети: ответы модели недоступны» above the panel, microphone disabled.
{BASE}
```
**P4 Correction detail (bottom sheet)**
```
Same style. {PHONE}. The conversation (dimmed) with a bottom sheet opened from the highlighted correction.
Sheet: title «Исправление», «seit zwei Tage → seit zwei Tagen», rule «seit + Dativ: Tagen», buttons «Скажу ещё раз» and «В словарь».
{BASE}
```
**P5 «Разговоры» (session list)**
```
Same style. {PHONE}. Tab «Разговоры» active. Segmented control «Немецкий | Английский | Все».
Search field «Поиск по разговорам». List rows with language accent dot, title, last line preview and date:
«У врача» — «Haben Sie auch Fieber?» — «Сегодня, 9:12»; «IELTS Part 2» — «I like to visit the old harbour…» — «Вчера, 19:40»;
«Работа: собеседование» — «Tell me about yourself.» — «24 окт.»; «Свободный разговор» — «Was hast du am Wochenende gemacht?» — «22 окт.».
Floating primary button «Новый разговор». Sync status line «Синхронизировано в 9:14».
{BASE}
```
**P6 New session (sheet)**
```
Same style. {PHONE}. Full-height sheet «Новый разговор».
Language segmented «Немецкий | Английский»; mode chips «Вопросы», «Свободный разговор», «Свой промпт», «Сценарий»;
fields «Тема» (placeholder «например: у врача»), «Роль собеседника» (placeholder «например: врач»), «Уровень» chips «A2 B1 B2 C1»;
«Исправление ошибок» toggles «По ходу» (on), «После разговора» (on), «По запросу»; «Кто начинает» segmented «Lingo | Я»;
bottom buttons «Отмена» and «Начать».
{BASE}
```
**P7 Hints / phrases panel (sheet over the conversation)**
```
Same style. {PHONE}. Bottom sheet «Подсказки» over the dimmed conversation, tabs «Фразы темы», «Исправления», «Как сказать», «Словарь ★».
Cards: «Ich habe Kopfschmerzen.» — «У меня болит голова.»; «Seit wann haben Sie Fieber?» — «С какого времени у вас температура?»;
each card with a speaker icon and a star.
{BASE}
```
**P8 Recap card (end of session)**
```
Same style. {PHONE}. End-of-session summary «Итог занятия · 30 мин».
Sections: «Главные ошибки» with three rows «seit zwei Tage → seit zwei Tagen», «ich habe gegangen → ich bin gegangen», «in die Apotheke gehen ✓»;
«Фразы для повторения» with two phrases and speaker icons; «Дальше: попробуйте сценарий „В аптеке“».
Buttons «В разминку» and «Готово». No pronunciation scores.
{BASE}
```
**P9 Sign-in (web PWA on phone)**
```
Same style. {PHONE}. First screen of the web app: the Lingo mark large, title «Lingo», subtitle «Разговорная практика: немецкий и английский»,
primary button «Войти через GitHub» (with a neutral GitHub-style octocat outline icon), small text «Доступ только для владельца».
{BASE}
```
**P10 First run — privacy and microphone**
```
Same style. {PHONE}. Onboarding step «Шаг 1 из 3»: title «Микрофон и голос», a live input-level meter, button «Проверить голос»,
privacy box «Что хранится: текст разговоров. Аудио уходит на распознавание и не сохраняется.», buttons «Назад» and «Дальше».
{BASE}
```
**P11 Settings and Resources**
```
Same style. {PHONE}. Settings list grouped: «Голос» (rows «Голос для немецкого», «Голос для английского», «Темп речи»),
«Разговор» («Пауза окончания фразы», «Режим микрофона»), «Язык интерфейса» («Русский»), «Ресурсы на сегодня» (a compact usage bar
«Основная модель · 62 из 130 ходов», «Резерв · свободно»), «Данные» («Экспорт», «Удалить мои данные» in red), «Выйти».
{BASE}
```

### 4.2 Mac (landscape, {MAC})
**M1 Main window — conversation**
```
Same style as the attached board. {MAC}. Theme {dark|light}. New desktop layout (clean slate):
left sidebar with sections «Сегодня», «Разговоры», «Словарь», «Прогресс» and below it the session list (rows «У врача», «IELTS Part 2», «Работа: собеседование»);
centre: the German conversation from §2.4 with the in-bubble correction, header «У врача · Немецкий · B1», source chip «Groq · 120b»;
bottom: voice panel with microphone, state «Говорю», waveform in the German accent, «Пауза», «Завершить», toggles «По-русски», «Медленно», and a text field «Напишите сообщение…»;
right: collapsible «Подсказки» column with two hint cards.
{BASE}
```
**M2 Main window — «Сегодня» on the desktop**
```
Same style. {MAC}. The «Сегодня» view in the centre: day plan 4 × 30 min as four wide cards, warm-up block, streak, «Продолжить разговор»; sidebar as in M1; no hints column.
{BASE}
```
**M3 Voice states strip**
```
Same style. 1536×1024 sheet showing only the Mac voice panel in seven states stacked vertically, each labelled with its state text:
«Нажмите и говорите», «Запись», «Слушаю», «Думаю…», «Говорю», «Пауза», «Нет сети: ответы модели недоступны».
{BASE}
```
**M4 Settings window**
```
Same style. {MAC} sized 900×700. Settings with a top tab bar «Ключи и модели», «Квота», «Голос», «Синхронизация», «Данные» («Ключи и модели» active):
provider card «Groq» with two masked keys «Ключ 1 ••••rRZg» and «Ключ 2 ••••8kQa (доп. аккаунт)», buttons «Проверить», «Удалить», «Добавить»;
card «Порядок цепочки» with three draggable rows «Groq · gpt-oss-120b», «Groq · gpt-oss-20b», «Cloudflare · gpt-oss-20b».
{BASE}
```
**M5 New session, edit transcript, onboarding** (three images, same window)
```
Same style. {MAC}. (a) Modal «Новый разговор» with the same fields as phone P6, laid out in two columns.
(b) Modal «Исправить расшифровку» with a text field containing «Ich habe seit zwei Tage Kopfschmerzen.», buttons «Отмена», «Сохранить», «Ответить заново».
(c) First-run window «Добро пожаловать в Lingo», «Шаг 1 из 3», «Микрофон и распознавание речи», button «Разрешить».
{BASE}
```

### 4.3 iPad and web desktop
**T1 iPad landscape conversation** — `Same style. {IPAD}. Same content and layout idea as M1, touch-sized (44-pt targets), sidebar collapsible. {BASE}`
**W1 Web desktop** — `Same style. {WEB}. Same as M1 rendered in a browser, signed-in avatar menu top-right with «Выйти». {BASE}`

---

## 5. Phase 3 — teacher features (concepts, phone + one Mac view each)

**F1 Warm-up (spaced repetition)**
```
Same style. {PHONE}. «Разминка · 3 из 6». A flash card: prompt «Скажи правильно:», the learner's past phrase «Ich wohne in Hamburg seit zwei Jahre»,
hidden answer area with button «Показать ответ», big microphone button «Скажу вслух», small text «Повтор через 3 дня»; progress dots on top.
{BASE}
```
**F2 Warm-up answer**
```
Same style and card. Answer revealed: «Ich wohne seit zwei Jahren in Hamburg», rule «seit + Dativ, место после времени», buttons «Было трудно», «Нормально», «Легко».
{BASE}
```
**F3 Scenarios catalogue**
```
Same style. {PHONE}. «Сценарии» with categories as horizontal chips «Жизнь в Германии», «Работа», «Экзамены», «Свободный разговор»;
cards «У врача», «Bürgeramt: прописка», «Аренда квартиры», «Звонок в банк» with level badges «A2», «B1» and the German accent;
section «Экзамены»: «Немецкий B1 · Goethe / telc», «Английский · IELTS Speaking».
{BASE}
```
**F4 Exam mode — German B1**
```
Same style. {PHONE}. «Экзамен B1 · Часть 2 · Презентация темы». Topic card «Wohnen in der Stadt oder auf dem Land?»,
five step chips «Тема», «Опыт», «Ситуация в стране», «Плюсы и минусы», «Мнение»; timer «Подготовка 02:15»; button «Начать ответ».
{BASE}
```
**F5 Exam mode — IELTS Part 2**
```
Same style. {PHONE}. «IELTS Speaking · Part 2». Cue card «Describe a place you like to visit. You should say: where it is, when you go there, what you do there, and explain why you like it.»,
timers «1:00 подготовка» and «2:00 ответ», note field «Заметки», button «Говорить».
{BASE}
```
**F6 Exam feedback**
```
Same style. {PHONE}. «Разбор ответа»: three criteria bars «Беглость и связность», «Словарный запас», «Грамматика» with short comments;
grey note «Произношение не оценивается»; examples «Было → Лучше»; buttons «Повторить часть» and «Сохранить в разминку».
{BASE}
```
**F7 Progress**
```
Same style. {PHONE}. Tab «Прогресс» active. Weekly bar chart of minutes per day (DE and EN accents stacked), totals «4 ч 10 мин за неделю»,
«Повторено карточек: 74», chart «Ошибки по типам» with rows «Артикли», «Порядок слов», «Падежи», «Времена» trending down,
level chips «Немецкий · B1», «Английский · B2».
{BASE}
```
**F8 Weekly report**
```
Same style. {PHONE}. «Отчёт за неделю · 20–26 октября». Sections «Сильные стороны» (three bullets), «Фокус на неделю» (three bullets),
«Рекомендуемые сценарии» (two cards), button «Начать неделю».
{BASE}
```
**F9 Memory about me**
```
Same style. {PHONE}. «Что Lingo знает обо мне»: editable rows «Цель: экзамен B1 в декабре», «Живу в Hamburg», «Работа: контент-менеджер»,
«Частая ошибка: порядок слов после „weil“»; each row with edit and delete icons; button «Удалить всё».
{BASE}
```
**F10 Mac — progress dashboard** — `Same style. {MAC}. Desktop «Прогресс» view combining F7 and F8 in a two-column dashboard. {BASE}`

---

## 6. Phase 4 — design system, mark, icon

**S1 Colour sheet**
```
Same style. 1536×1024 design-system sheet «Lingo · Colours», dark and light side by side: background, surface 1/2/3, text primary/secondary/tertiary,
border, accent German, accent English, success, warning, danger; each swatch labelled with a token name in English (e.g. "bg.window", "accent.de") and a HEX value.
Labels in a clean monospace. {BASE}
```
**S2 Typography sheet** — `Same style. Sheet «Lingo · Type» showing the SF Pro scale with token names (title, headline, body, bubble, caption, meta) in English and a Russian + German + English sample line for each: «Продолжить разговор», «Guten Morgen!», «Describe a place». {BASE}`
**S3 Components sheet** — `Same style. Sheet «Lingo · Components»: buttons (primary, secondary, destructive, round icon), chips, segmented control, tab bar, list row, message bubbles (assistant, learner, learner with correction), hint card, voice panel, toggle, text field, bottom sheet, banner; each labelled in English. {BASE}`
**S4 Lingo mark**
```
Same style. 1024×1024. The Lingo mark alone in four variants: monochrome on dark, monochrome on light, German accent, English accent,
plus a 3-frame "breathing" sequence (scale 100 % → 106 % → 100 %) used while the assistant speaks. No text.
```
**S5 App icon**
```
Same style. 1024×1024 macOS/iOS app icon for "Lingo": the Lingo mark centred on a rounded-square (squircle) background in the direction's main surface colour,
subtle depth, readable at 32 px, no text, no flags. Show the icon large and at small sizes (128, 64, 32) next to it.
```

---

## 7. Iteration prompts

### 7.1 Fix garbled text
`Keep everything exactly the same; only fix the text so that it reads exactly: «…», «…». Use SF Pro, correct Russian spelling, no other changes.`
### 7.2 Consistency
`Match the attached approved screen exactly in colours, radii, spacing, icon style and typography; only change the content to: …`
### 7.3 Theme switch
`Recreate the attached screen in the {light|dark} theme of the same direction; identical layout and content.`
### 7.4 Simplify
`Remove decorative elements and reduce to the essential content; keep the layout grid and the accents.`
### 7.5 Accessibility check
`Increase contrast of secondary text to at least 4.5:1 against its background; keep everything else identical.`

---

## 8. Phase 5 — architecture illustrations (for README and presentations; English labels)

**A1 System context**
```
Clean technical illustration, 1536×1024, isometric-lite flat style matching the chosen direction's palette, white or dark background.
Boxes and arrows: "Lingo for Mac (Swift, on-device speech recognition)", "Lingo Web (PWA on iPhone, iPad, Android, Windows)",
"Lingo Engine (Cloudflare Worker + D1)", "Groq (chat + Whisper)", "Workers AI (fallback)", "GitHub sign-in".
Arrows labelled "HTTPS / SSE", "sync", "chat + transcription". Legible English labels only, no extra text.
```
**A2 A voice turn**
```
Same illustration style. Left-to-right pipeline: "You speak" → "Voice detection" → "Recognition (Whisper)" → "Prompt + model (Groq)" →
"Reply streamed" → "Spoken by the device voice", with a dashed loop "Interrupt any time". Small timing badges "≈ 0.5 s", "≈ 1 s", "first sentence". 
```
**A3 History and sync**
```
Same illustration style. Three devices (Mac, iPhone, iPad) each writing "events" into one "Account history (D1)", arrows "push / pull", a note "no duplicates, no losses";
a lock icon "GitHub sign-in, owner only".
```

---

## 9. Checklist before Phase 3 of the redesign task (DESIGN.md v2)
- [ ] Direction chosen by the owner (A / B / C), dark and light boards approved
- [ ] All P1–P11, M1–M5, T1, W1 screens generated in both themes and approved
- [ ] Teacher concepts F1–F10 approved (concepts only, no code)
- [ ] S1–S5 sheets approved — these become the source for DESIGN.md v2 tokens
- [ ] Every image saved with its prompt (§0.5); text verified letter by letter
