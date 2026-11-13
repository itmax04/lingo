# Reply options — evidence (M-11b, #140)

## Screenshots (MAC-32)
`apps/mac/.build/debug/Lingo --ui-snapshot <png> --ui-reply-options --ui-theme light|dark` renders the conversation on synthetic fixtures.
Files in `reply-options/`: `first-words`, `one-revealed`, `all-revealed`, `refresh-error`, `collapsed`, `none` (No options for this turn), each in `-light` and `-dark`.
- English UI: PASS (12 images).
- Russian UI: **NOT RUN.** The debug build does not compile the String Catalog (only `build-app.sh` does), so `-AppleLanguages (ru)` renders English. Every new string has a Russian entry; `scripts/check-design.py` checks the bilingual catalog. Capture Russian screenshots from `dist/Lingo.app` at the owner's rebuild.
- Reference image: none (MR-51); the ±4 pt criterion of DESIGN.md §8 is not claimed.

## Token cost (MAC-33, MR-54)
**NOT RUN.** It needs six single daytime requests (three with the switch on, three off, same turns) and one refresh with real provider keys, which only the signed app on the owner's Mac can read (AGENTS.md §6.2, §6.5). Prompt side already measured in M-11a: +131 characters ≈ 37 estimated tokens. The MR-54 decision (three lines or two) stays open until these measurements are recorded here; no rule change is made without them.

Method for the owner's Mac: turn the switch on in an ordinary session, run three turns, read `prompt_tokens`/`completion_tokens` per request from the usage log (Settings → Quota, purpose `dialog`, `replyOptions` for refresh); repeat the same three turns with the switch off; if the median completion increase is above 100 tokens, ask for two options in `replyProtocolLine`.
