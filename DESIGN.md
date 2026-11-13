# DESIGN.md — Lingo Quiet, version 2

Change: LINGO-07, issue #32. Status: implementation specification; generated references remain subject to the evidence audit. This document supersedes the former dark-only visual system. The executor selected A Quiet under the owner's autonomous instruction.

## 1. Principles and boundaries

Use calm, flat surfaces, readable text and a compact voice control area. Conversation text is the primary content. The mark is an abstract pair of overlapping loops, never a robot or a person. A thin waveform reflects captured levels. No pronunciation assessment, microphone quality score or invented learner statistics.

Existing Mac actions remain unchanged. Today, standalone Vocabulary, Progress and Teacher are explicit Coming soon previews. Existing saved phrases remain usable in the conversation's Vocabulary hints section. Accounts, web, mobile, exams, review scheduling and teacher logic in reference images describe future work only.

## 2. Colors

Dynamic sRGB colors resolve per window appearance. Theme.swift is the executable mapping. The following HEX values are exact, not sampled from generated pixels.

| Token | Light | Dark |
|---|---|---|
| `bgWindow` | `#F7F6F3` | `#111315` |
| `bgSidebar` | `#F0EFEB` | `#16191C` |
| `bgHints` | `#F7F6F3` | `#16191C` |
| `surfaceCard` | `#FFFFFF` | `#1D2125` |
| `surfaceBubbleAssistant` | `#FFFFFF` | `#20262A` |
| `surfaceRowSelected` | `#E4E4DE` | `#2B3136` |
| `surfaceControl` | `#EBECE8` | `#2B3136` |
| `surfaceSendButton` | `#855107` | `#F2B85B` |
| `borderSubtle` | `#D3D7D9` | `#343A40` |
| `accentGerman` | `#855107` | `#F2B85B` |
| `accentEnglish` | `#136C61` | `#62D5C5` |
| `bubbleUser` | `#F3E9D9` | `#29241C` |
| `avatarBotBg` | `#F3E9D9` | `#352A1A` |
| `statusDanger` | `#A52A32` | `#FF9CA2` |
| `statusSuccess` | `#216A49` | `#86D8AD` |
| `textPrimary` | `#202428` | `#F5F4F0` |
| `textSecondary` | `#505A63` | `#B5BBC1` |
| `textTertiary` | `#5D676F` | `#9DA5AC` |
| `iconSend` | `#FFFFFF` | `#202428` |

German accent surfaces: light #F3E9D9, dark #352A1A. English accent surfaces: light #E4F2EE, dark #19332F. Use explicit DE/EN labels as well as color, never flags. Primary button text: light #FFFFFF, dark #202428. Primary button fill, selected navigation, focus rings and tint: `Theme.accent(currentStudyLanguage)` (German amber or English teal).

## 3. Typography

Use system SF Pro through Font.system; no bundled or paid font files. Logo 28 semibold; page title 24 semibold; panel title 18 semibold; conversation 16 regular; hint phrase 15 medium; button 14 medium; row 14 regular; subtitle/translation 13 regular; metadata/caption/section 12. State labels 14 medium. Text remains selectable in conversation content and errors. Preserve Russian and English translations; user language data is not translated.

## 4. Geometry

Spacing uses 4 pt increments: 4, 8, 12, 16, 20, 24, 32. Hairlines 1 pt and optical icon strokes are exceptions. Main reference canvas 1280×800 pt; sidebar 232 pt; hints 272 pt; header 80 pt. The hints column collapses below 1280 pt; minimum supported Mac content size 1100×700 pt. Do not fabricate a mobile-sized native Mac window.

Conversation gaps 24 pt; bubble padding 16 pt; avatar/mark 32 pt with 12 pt gap; bubble maximum fraction 0.82. Primary button height 44 pt; voice panel height 112 pt; microphone target 44 pt; secondary voice control 36 pt plus caption. Input height 48 pt. Card/button radius 12 pt; bubble radius 16 pt. Settings navigation 200 pt; new-session content 820×680 pt; onboarding 720×560 pt; transcript editor 520×320 pt.

Content shadow token: none (opacity 0, blur 0, x 0, y 0). Native floating popovers retain the system window shadow; that system effect is not claimed to match generated shadows. The app icon is the permitted raster exception.

## 5. Components and states

- Sidebar: mark, product name, five navigation entries, language filter, new session, real session history, sync status and Settings. Planned entries visibly say Coming soon.
- Conversation: assistant on the left, learner on the right; inline original word struck through with corrected word beside it. Correction detail shows original, corrected text and explanation; original journal data is retained. Unattachable fixes remain a separate block.
- Reply state: idle, recording, listening, thinking, speaking, paused. Network, quota and chain failures use explicit text and an error symbol. Do not infer new business states or alter voice transitions.
- Voice panel: one compact rectangle; state label, level line, microphone, pause/resume, finish and existing toggles. No giant decorative orb.
- Hints: Topic phrases, Corrections, How to say, Vocabulary ★. Preserve playback and starring behavior.
- Reply options (LINGO-09 MR-49…MR-54): a `surfaceCard` block with a hairline `borderSubtle` stroke and 12 pt radius under the latest model message, aligned with the bubble text. Header: collapse chevron, "Reply options" (section style), "Show all" (caption, accent) and refresh. Each option is a `surfaceControl` row (12 pt radius, 12/8 pt padding): first words and "…" with an eye symbol; once revealed the phrase (hint phrase style), the translation (`textSecondary`) and ▶ ★ Insert. Errors use `statusDanger` with a warning symbol and text. The block hides while the learner's next turn runs; the voice-panel chip uses the existing chip style. No new colors, sizes or shadows; no reference image (implementation screenshots in `docs/changes/LINGO-09/evidence/reply-options/`).
- Settings: provider/model keys, quotas, voice, sync and data. Additional account is a label on an existing key, not a promise of quota independence.
- Forms and alerts: keyboard default/cancel actions, clear labels, visible validation and destructive intent. Never execute exports or deletion during screenshot capture.

## 6. Motion and accessibility

Transitions 180 ms ease-in-out. Speaking mark breathing scale 1.00–1.06 over 1.2 s. Reduce Motion disables breathing and animated scrolling and replaces the animated waveform with a level meter. No required information depends on motion or color alone. Keep keyboard focus, native controls and VoiceOver labels. Native controls use the platform focus ring; custom buttons add a 2 pt accent outline with a 4 pt inset. Hover is not the only state indication.

Light `textTertiary` is #5D676F to make the hierarchy lighter than #505A63 secondary text while retaining at least 4.5:1 even on selected rows.

Normal text must achieve at least 4.5:1 against its actual surface. `contrast.json` records token-pair calculations; `check-design.py` independently computes WCAG sRGB luminance from `tokens.json` for every required pair. Disabled controls are exempt from WCAG text contrast, but descriptions and Coming soon labels remain full-opacity readable text. Decorative dividers are not text and are not certified by the text contrast table.

## 7. Future platform adaptation

Phone uses one column with bottom navigation Today / Conversations / Vocabulary / Progress; primary voice actions stay within thumb reach with at least 44 pt targets and safe-area padding. Hints become a sheet. iPad uses adaptive two/three columns in landscape and collapsible secondary content in portrait. Web uses the same token values as CSS variables and `system-ui, -apple-system, BlinkMacSystemFont, sans-serif`; Windows and Android use system fallback fonts without downloading SF Pro. Native Live Activity and Dynamic Island are concepts, not implemented capabilities.

## 8. Reproducibility and evidence

Generated gradients, blurred edges, inconsistent marks, text shaping and variable canvas dimensions are not executable specifications. Replace them with flat token colors, native SF typography and the vector LingoGlyph. The permitted app-icon bitmap is a separate asset; generated screenshots are never embedded in UI.

Preserve original ImageGen outputs and exact prompts. Normalize comparison canvases with recorded scaling only; do not claim pixel agreement from resampling. Every Mac screen requires reference | implementation evidence in both themes. The ±4 pt acceptance criterion remains unpassed until measured; all larger differences stay listed in the report. Autonomous choice is not owner approval of a deviation.

## 9. Web adaptation (carried over from main)

> Status: written against the v1 dark tokens before DESIGN.md v2. Section 7 and the v2 token tables above win on any difference; rebase this section on v2 in LINGO-03 P-15 (Web UI).

- **Tokens → CSS custom properties** with the same names (`--bg-window`, `--surface-card`, `--type-bubble-size`, …). 1 pt in this file = **1 CSS px**.
- **Font stack:** `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif` — Cyrillic and Latin in every member; system fonts only, no web-font downloads.
- **Wide layout (≥ 1100 px):** the three columns of the mockup with the widths of §3; the hints column becomes a slide-over below 1280 px (as R-40).
- **Narrow layout (< 1100 px; phones, iPad portrait):** one column — header (session title, source badge, menu), feed, voice panel, input. The session list and the hints open as full-height slide-over panels from the left and the right. (added, LINGO-03)
- **Touch:** interactive targets ≥ **44 px**; the voice panel and the input stay above the on-screen keyboard and inside safe areas (`env(safe-area-inset-*)`). (added, LINGO-03)
- **Phone voice panel:** the microphone circle grows to **64 px** for one-handed use; Pause/Finish stay 44 px. (added, LINGO-03 — proposal, confirm at acceptance)
- **Motion:** CSS transitions 200 ms ease-in-out only; `prefers-reduced-motion: reduce` disables them and replaces the waveform with a static level bar.
- **Focus:** a visible 2 px `accent.primary` ring for keyboard navigation (`:focus-visible`).
- **Icons:** simple inline SVGs in regular weight matching SF Symbols; a third-party icon set only after it is added to the ADR-0002 allow-list.
- **PWA colours:** theme colour `bg.titlebar` (`#1B2125`), background `bg.window`.
