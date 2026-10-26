# DESIGN.md — Lingo

Source: the owner's mockup [docs/design/lingo-mac.webp](docs/design/lingo-mac.webp) (1774×887 px), owner's choice Q15 of 2026-10-25.
Colours were sampled from the mockup on 2026-10-25 (the most frequent pixel colour in the element's area). Sizes were converted from mockup pixels
to pt with a factor of **1.44** (the window in the mockup ≈ 1730 px ≈ 1200 pt). **Do not invent values that are not here.** If something is missing,
the executor adds the value here marked "(added, <step>, reason)" and shows it to the owner at acceptance.

Platforms: macOS (SwiftUI) since LINGO-01; the web (PWA) since LINGO-03 — see §9 for the web adaptation (owner decision O-20: adapt this file, one column on phones).
Theme: **dark only** in v1. The mockup has no light theme; its values are not invented.

## 1. Colours
| Token | HEX | Where in the mockup |
|---|---|---|
| `bg.window` | `#121619` | Message feed background |
| `bg.sidebar` | `#14181B` | Left column |
| `bg.hints` | `#161A1E` | Right column |
| `bg.titlebar` | `#1B2125` | Window title bar |
| `surface.card` | `#1F252A` | Hint cards, English/Deutsch segment track |
| `surface.voicePanel` | `#171D22` | Voice panel |
| `surface.input` | `#181F21` | Input field |
| `surface.bubbleAssistant` | `#242E38` | Assistant bubble |
| `surface.rowSelected` | `#232C39` | Selected session in the list |
| `surface.control` | `#283039` | Round "Pause" button |
| `surface.sendButton` | `#333D47` | Round send button |
| `surface.chip` | `#101719` | Source badge ("On device") |
| `border.subtle` | `#23292E` | Outline of cards, badge, voice panel and input field |
| `border.divider` | `#272B2E` | Column dividers |
| `accent.primary` | `#1162F4` | "New session", active segment |
| `bubble.user` | `#105DEB` | User bubble |
| `avatar.userBg` | `#1B324F` | User avatar circle |
| `avatar.userIcon` | `#4075D1` | Person icon |
| `avatar.botBg` | `#274246` | Assistant avatar circle |
| `avatar.botIcon` | `#87EBE0` | Robot icon |
| `voice.accent` | `#5BF2DF` | "Listening", waveform, microphone icon |
| `voice.accentSoft` | `#1C433F` | Microphone circle on the panel |
| `status.danger` | `#E64542` | "Finish" button |
| `status.success` | `#1FD67F` | Status dot in the source badge |
| `text.primary` | `#FFFFFF` | Titles, bubble text, session names |
| `text.secondary` | `#AAB3BF` | Subtitle, session dates, phrase translations, "My sessions" |
| `text.tertiary` | `#848B97` | Input placeholder, idle icons |
| `text.metaOnAccent` | `#AFE8FF` | Time and ✓✓ on the blue bubble |
| `icon.send` | `#E7EFF8` | "Send" icon |

`text.secondary` was derived from anti-aliased text pixels (the lightest pixel #C7D2E1 minus anti-aliasing). It is checked against the mockup with a screenshot at acceptance.

## 2. Typography
Font: the system SF Pro (`.system`); Cyrillic and Latin in one font. Sizes in pt:
| Token | Size / weight | Where |
|---|---|---|
| `type.logo` | 30 / bold | "Lingo" |
| `type.title` | 22 / semibold | Session title in the header |
| `type.subtitle` | 14 / regular, `text.secondary` | "Free conversation in English" |
| `type.button` | 16 / medium | "New session" |
| `type.segment` | 14 / medium | English / Deutsch |
| `type.section` | 13 / regular, `text.secondary` | "My sessions", "Useful phrases for this topic" |
| `type.rowTitle` | 14 / regular | Session title in the list |
| `type.rowMeta` | 12 / regular, `text.secondary` | "Today, 14:28" |
| `type.bubble` | 17 / regular | Message text |
| `type.meta` | 11 / regular | Time in bubbles, "provider · model" label |
| `type.panelTitle` | 17 / semibold | "Hints" |
| `type.hintPhrase` | 16 / semibold | Hint phrase |
| `type.hintTranslation` | 13 / regular, `text.secondary` | Translation |
| `type.voiceState` | 16 / semibold, `voice.accent` | "Listening" |
| `type.caption` | 11 / regular | "Pause", "Finish" under the buttons |
| `type.chip` | 13 / regular | "On device" |

Dynamic Type is not used on macOS. Minimum text size: 11 pt.

## 3. Spacing and grid
Base step: 4 pt. Only these values are used: **4, 8, 12, 16, 20, 24, 32**.
| Token | Value | Where |
|---|---|---|
| `layout.sidebarWidth` | 256 pt | Left column |
| `layout.hintsWidth` | 264 pt | Right column (collapses below a window width of 1280, R-40) |
| `layout.headerHeight` | 72 pt | Center column header |
| `space.columnPadding` | 16 pt | Column inner padding |
| `space.messageGap` | 16 pt | Between messages |
| `space.bubblePaddingH` / `V` | 16 / 12 pt | Inside a bubble |
| `space.avatarGap` | 12 pt | Avatar ↔ bubble |
| `space.rowPadding` | 12 pt | Session row |
| `space.cardGap` | 12 pt | Between hint cards |

Bubble width: at most 70% of the center column.

## 4. Radii and element sizes
| Token | Value |
|---|---|
| `radius.button` | 8 pt ("New session", segment, session row) |
| `radius.bubble` | 16 pt |
| `radius.card` | 10 pt (hint cards) |
| `radius.capsule` | half the height (voice panel, input field, source badge) |
| `size.primaryButtonHeight` | 40 pt |
| `size.segmentHeight` | 36 pt |
| `size.rowHeight` | 50 pt |
| `size.avatar` | 40 pt, circle |
| `size.voicePanelHeight` | 86 pt |
| `size.micCircle` | 50 pt |
| `size.roundButton` | 44 pt (Pause, Finish) |
| `size.inputHeight` | 48 pt |
| `size.sendButton` | 40 pt |
| `size.hintCardMinHeight` | 78 pt |
| `size.chipHeight` | 32 pt |
| `stroke.subtle` | 1 pt, `border.subtle` |
| `size.waveBar` / `space.waveGap` | 3 / 4 pt (added, P-01 of LINGO-01: waveform bars in the mockup ≈ 4 px wide with ≈ 6 px pitch) |
| `size.statusDot` | 12 pt (added, P-01 of LINGO-01: the dot in the source badge ≈ 16 px in the mockup) |

## 5. Components
- **Session row.** "Bubble" icon in `text.tertiary`, title `type.rowTitle`, date `type.rowMeta`, "…" on the right.
  Selected: background `surface.rowSelected`. Hover: the same background at 50% opacity.
- **Language segment.** Track `surface.card`; active segment `accent.primary` + `text.primary`; inactive `text.secondary`.
- **User bubble.** Background `bubble.user`, on the right. Bottom right: time + ✓/✓✓ in `text.metaOnAccent`. Avatar to the right (`avatar.userBg`/`avatar.userIcon`).
- **Assistant bubble.** Background `surface.bubbleAssistant`, on the left, robot avatar (`avatar.botBg`/`avatar.botIcon`). Time in `text.secondary`.
  - `@fix` correction block inside the bubble: outline `stroke.subtle`, radius `radius.card`.
  - Russian segment (R-17): background `surface.card` inside the bubble.
  - Interrupted part: `text.tertiary`.
- **Voice panel.** Capsule `surface.voicePanel` + `stroke.subtle`.
  - Left: circle `voice.accentSoft` with a microphone icon in `voice.accent`, state label `type.voiceState`.
  - Center: waveform bars in `voice.accent`, fading towards the edges (opacity 100% → 30%).
  - Right: "Pause" (`surface.control`) and "Finish" (`status.danger`) buttons, captions `type.caption`.
- **Input field.** Capsule `surface.input` + `stroke.subtle`, keyboard icon `text.tertiary`, vertical divider `border.divider`, placeholder `text.tertiary`.
  Send button: circle `surface.sendButton`, icon `icon.send`.
- **Source badge.** Capsule `surface.chip` + `stroke.subtle`, dot `status.success` (or `status.danger` when offline), text `type.chip`, chevron.
- **Hint card.** `surface.card` + `stroke.subtle`, `radius.card`. Phrase `type.hintPhrase`, translation `type.hintTranslation`, speaker icon on the right, ★ next to it.
  Icons idle in `text.primary`; an active ★ in `accent.primary`.

Icons: SF Symbols, regular weight, sized to the line's text.

## 6. States
- **Keyboard focus:** the system macOS focus ring (accent colour `accent.primary`).
- **Hover:** buttons get lighter. No separate colours: `opacity(0.85)` over the original.
- **Disabled:** `opacity(0.4)` and a hint with the reason (R-33, S-01).
- **Error:** text in `status.danger` under the element.

## 7. Motion
- Only system SwiftUI animations (`.default`, `.easeInOut` 0.2 s) for appearing messages and panel state changes.
- The waveform follows the sound level; no decorative animation.
- With "Reduce motion" (`accessibilityReduceMotion`) the waveform becomes a static level bar and transitions are not animated.

## 8. Accessibility
- Contrast of `text.primary` and `text.secondary` against the column backgrounds ≥ 4.5:1 (check and record in handoff).
- Every icon button has an accessibility label (localized).
- Keyboard: space (hold to talk), Esc (stop), ⌥R ("I'm speaking Russian"), ⌘N (new session), ⌘, (settings).

## 9. Web adaptation (LINGO-03; added by the architecture of 2026-10-26, to be confirmed by the owner at acceptance)
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
