# Lingo final visual direction — 2026

Direction A, Quiet, is selected by the executor under the owner's autonomous instruction. These are generated references, not owner-approved pixel specifications. All future platforms and teacher screens are concepts. Only existing Mac behavior and navigation placeholders are implemented in LINGO-07. LINGO-03 and issues #3–#30 remain paused.

The canonical implementation specification is DESIGN.md v2. Exact prompts accompany the originals. The evidence manifest distinguishes generation, inspection, retries and implementation. Generated images are never used as UI backgrounds.

## Direction assessment (1–5)

| Criterion | A Quiet | B Warm | C Premium |
|---|---:|---:|---:|
| R-01…R-12 alignment | 3 | 3 | 3 |
| Cyrillic legibility | 5 | 5 | 5 |
| Contrast in initial references | 3 | 2 | 2 |
| Consistency | 3 | 4 | 4 |
| One-handed phone use | 4 | 4 | 4 |
| SwiftUI/CSS feasibility | 5 | 4 | 3 |
| Total | 23 | 22 | 21 |

The initial boards are qualitative comparisons; contrast scores do not certify WCAG. A is easiest to reproduce with native controls and restrained surfaces. Its subdued labels and inconsistent mark need correction in the final system. Token contrast is measured separately.

## Evidence and limits

- Original ImageGen output dimensions may differ from requested dimensions encoded in prompt filenames. Original files are preserved; comparison canvases explicitly record any scaling.
- Generated text, geometry and decorative marks require inspection. A completed generation is not an accepted screen.
- A screenshot comparison is not evidence that audio, network, accounts, exams or future features work.
- Exact ±4 pt fidelity remains an acceptance check until the measurement report passes. Deviations must stay visible in the handoff.

## Current delivery status

**Blocked, not complete.** The subscription ImageGen service returned HTTP 429 `usage_limit_reached`. Its reset estimate was 2026-10-28 06:45 UTC (07:45 Berlin). No paid API was used. All 139 base/final assets exist, but remaining repairs and strict geometry acceptance are incomplete. Do not merge as an accepted final visual match.

There are 118 product screen/state mockups across both themes, six direction boards, eight system sheets, six architecture sheets and one production icon. `10-comparison/` contains 40 equal-canvas pairs and native fixture captures; the manifest records scaling and limitations. `10-comparison/imagegen-status.json` lists the remaining quota-blocked work. `text-audit.json` contains remaining OCR flags; OCR is assistance, not a proof of perfect lettering.

Mac uses native components and exact DESIGN.md v2 tokens. Future sections are Coming soon placeholders. All other platforms and teacher features are concepts. Native menus and correction details in fixture evidence are component previews, not captures of separate system popover windows. Voice, real Keychain, iCloud and provider sessions were not exercised.

Reproduce native captures with `scripts/build-app.sh` then `scripts/redesign-snapshots.sh`. The packaged .app contains both compiled String Catalogs. Some menus and service strings need a restart after changing the UI language. No OS language or privacy settings are modified.

## Asset map

### mac

- [conversation / speaking / dark](04-mac/mac-conversation-speaking-dark-1536x1024.png) — [exact prompt](prompts-used/mac-conversation-speaking-dark-1536x1024-attempt-2.md)
- [conversation / narrow / dark](04-mac/mac-conversation-narrow-dark-1536x1024.png) — [exact prompt](prompts-used/mac-conversation-narrow-dark-1536x1024-attempt-3.md)
- [today / overview / dark](04-mac/mac-today-overview-dark-1536x1024.png) — [exact prompt](prompts-used/mac-today-overview-dark-1536x1024-attempt-2.md)
- [voice / states / dark](04-mac/mac-voice-states-dark-1536x1024.png) — [exact prompt](prompts-used/mac-voice-states-dark-1536x1024-attempt-2.md)
- [settings / keys / dark](04-mac/mac-settings-keys-dark-1536x1024.png) — [exact prompt](prompts-used/mac-settings-keys-dark-1536x1024.md)
- [settings / quota / dark](04-mac/mac-settings-quota-dark-1536x1024.png) — [exact prompt](prompts-used/mac-settings-quota-dark-1536x1024.md)
- [settings / voice / dark](04-mac/mac-settings-voice-dark-1536x1024.png) — [exact prompt](prompts-used/mac-settings-voice-dark-1536x1024-attempt-2.md)
- [settings / sync / dark](04-mac/mac-settings-sync-dark-1536x1024.png) — [exact prompt](prompts-used/mac-settings-sync-dark-1536x1024-attempt-2.md)
- [settings / data / dark](04-mac/mac-settings-data-dark-1536x1024.png) — [exact prompt](prompts-used/mac-settings-data-dark-1536x1024.md)
- [new-session / form / dark](04-mac/mac-new-session-form-dark-1536x1024.png) — [exact prompt](prompts-used/mac-new-session-form-dark-1536x1024-attempt-2.md)
- [transcript / edit / dark](04-mac/mac-transcript-edit-dark-1536x1024.png) — [exact prompt](prompts-used/mac-transcript-edit-dark-1536x1024.md)
- [onboarding / microphone / dark](04-mac/mac-onboarding-microphone-dark-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-microphone-dark-1536x1024-attempt-2.md)
- [onboarding / keys / dark](04-mac/mac-onboarding-keys-dark-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-keys-dark-1536x1024.md)
- [onboarding / sync / dark](04-mac/mac-onboarding-sync-dark-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-sync-dark-1536x1024.md)
- [recap / complete / dark](04-mac/mac-recap-complete-dark-1536x1024.png) — [exact prompt](prompts-used/mac-recap-complete-dark-1536x1024.md)
- [dictionary / starred / dark](04-mac/mac-dictionary-starred-dark-1536x1024.png) — [exact prompt](prompts-used/mac-dictionary-starred-dark-1536x1024.md)
- [progress / soon / dark](04-mac/mac-progress-soon-dark-1536x1024.png) — [exact prompt](prompts-used/mac-progress-soon-dark-1536x1024.md)
- [teacher / soon / dark](04-mac/mac-teacher-soon-dark-1536x1024.png) — [exact prompt](prompts-used/mac-teacher-soon-dark-1536x1024-attempt-2.md)
- [session / menu / dark](04-mac/mac-session-menu-dark-1536x1024.png) — [exact prompt](prompts-used/mac-session-menu-dark-1536x1024.md)
- [correction / detail / dark](04-mac/mac-correction-detail-dark-1536x1024.png) — [exact prompt](prompts-used/mac-correction-detail-dark-1536x1024-attempt-2.md)
- [conversation / speaking / light](04-mac/mac-conversation-speaking-light-1536x1024.png) — [exact prompt](prompts-used/mac-conversation-speaking-light-1536x1024-attempt-2.md)
- [conversation / narrow / light](04-mac/mac-conversation-narrow-light-1536x1024.png) — [exact prompt](prompts-used/mac-conversation-narrow-light-1536x1024-attempt-3.md)
- [today / overview / light](04-mac/mac-today-overview-light-1536x1024.png) — [exact prompt](prompts-used/mac-today-overview-light-1536x1024-attempt-2.md)
- [voice / states / light](04-mac/mac-voice-states-light-1536x1024.png) — [exact prompt](prompts-used/mac-voice-states-light-1536x1024-attempt-2.md)
- [settings / keys / light](04-mac/mac-settings-keys-light-1536x1024.png) — [exact prompt](prompts-used/mac-settings-keys-light-1536x1024-attempt-2.md)
- [settings / quota / light](04-mac/mac-settings-quota-light-1536x1024.png) — [exact prompt](prompts-used/mac-settings-quota-light-1536x1024-attempt-2.md)
- [settings / voice / light](04-mac/mac-settings-voice-light-1536x1024.png) — [exact prompt](prompts-used/mac-settings-voice-light-1536x1024-attempt-2.md)
- [settings / sync / light](04-mac/mac-settings-sync-light-1536x1024.png) — [exact prompt](prompts-used/mac-settings-sync-light-1536x1024-attempt-2.md)
- [settings / data / light](04-mac/mac-settings-data-light-1536x1024.png) — [exact prompt](prompts-used/mac-settings-data-light-1536x1024-attempt-2.md)
- [new-session / form / light](04-mac/mac-new-session-form-light-1536x1024.png) — [exact prompt](prompts-used/mac-new-session-form-light-1536x1024-attempt-2.md)
- [transcript / edit / light](04-mac/mac-transcript-edit-light-1536x1024.png) — [exact prompt](prompts-used/mac-transcript-edit-light-1536x1024-attempt-2.md)
- [onboarding / microphone / light](04-mac/mac-onboarding-microphone-light-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-microphone-light-1536x1024-attempt-3.md)
- [onboarding / keys / light](04-mac/mac-onboarding-keys-light-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-keys-light-1536x1024-attempt-2.md)
- [onboarding / sync / light](04-mac/mac-onboarding-sync-light-1536x1024.png) — [exact prompt](prompts-used/mac-onboarding-sync-light-1536x1024-attempt-2.md)
- [recap / complete / light](04-mac/mac-recap-complete-light-1536x1024.png) — [exact prompt](prompts-used/mac-recap-complete-light-1536x1024-attempt-2.md)
- [dictionary / starred / light](04-mac/mac-dictionary-starred-light-1536x1024.png) — [exact prompt](prompts-used/mac-dictionary-starred-light-1536x1024-attempt-2.md)
- [progress / soon / light](04-mac/mac-progress-soon-light-1536x1024.png) — [exact prompt](prompts-used/mac-progress-soon-light-1536x1024-attempt-2.md)
- [teacher / soon / light](04-mac/mac-teacher-soon-light-1536x1024.png) — [exact prompt](prompts-used/mac-teacher-soon-light-1536x1024-attempt-2.md)
- [session / menu / light](04-mac/mac-session-menu-light-1536x1024.png) — [exact prompt](prompts-used/mac-session-menu-light-1536x1024-attempt-2.md)
- [correction / detail / light](04-mac/mac-correction-detail-light-1536x1024.png) — [exact prompt](prompts-used/mac-correction-detail-light-1536x1024-attempt-2.md)

### iphone

- [today / overview / dark](02-iphone/iphone-today-overview-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-today-overview-dark-1024x1536.md)
- [conversation / speaking / dark](02-iphone/iphone-conversation-speaking-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-speaking-dark-1024x1536.md)
- [correction / detail / dark](02-iphone/iphone-correction-detail-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-correction-detail-dark-1024x1536.md)
- [conversations / list / dark](02-iphone/iphone-conversations-list-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversations-list-dark-1024x1536-attempt-2.md)
- [new-session / form / dark](02-iphone/iphone-new-session-form-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-new-session-form-dark-1024x1536.md)
- [hints / phrases / dark](02-iphone/iphone-hints-phrases-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-hints-phrases-dark-1024x1536.md)
- [recap / complete / dark](02-iphone/iphone-recap-complete-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-recap-complete-dark-1024x1536.md)
- [sign-in / github / dark](02-iphone/iphone-sign-in-github-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-sign-in-github-dark-1024x1536.md)
- [onboarding / microphone / dark](02-iphone/iphone-onboarding-microphone-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-onboarding-microphone-dark-1024x1536.md)
- [settings / resources / dark](02-iphone/iphone-settings-resources-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-settings-resources-dark-1024x1536.md)
- [conversation / idle / dark](02-iphone/iphone-conversation-idle-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-idle-dark-1024x1536.md)
- [conversation / recording / dark](02-iphone/iphone-conversation-recording-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-recording-dark-1024x1536.md)
- [conversation / listening / dark](02-iphone/iphone-conversation-listening-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-listening-dark-1024x1536.md)
- [conversation / thinking / dark](02-iphone/iphone-conversation-thinking-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-thinking-dark-1024x1536.md)
- [conversation / paused / dark](02-iphone/iphone-conversation-paused-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-paused-dark-1024x1536.md)
- [conversation / offline / dark](02-iphone/iphone-conversation-offline-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-offline-dark-1024x1536.md)
- [conversation / limit / dark](02-iphone/iphone-conversation-limit-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-limit-dark-1024x1536.md)
- [conversation / language-and-interruption / dark](02-iphone/iphone-conversation-language-and-interruption-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-language-and-interruption-dark-1024x1536.md)
- [dictionary / starred / dark](02-iphone/iphone-dictionary-starred-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-dictionary-starred-dark-1024x1536-attempt-2.md)
- [account / devices / dark](02-iphone/iphone-account-devices-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-account-devices-dark-1024x1536.md)
- [account / mac-connection / dark](02-iphone/iphone-account-mac-connection-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-account-mac-connection-dark-1024x1536.md)
- [data / export-delete / dark](02-iphone/iphone-data-export-delete-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-data-export-delete-dark-1024x1536.md)
- [native / locked-screen / dark](02-iphone/iphone-native-locked-screen-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-native-locked-screen-dark-1024x1536.md)
- [native / dynamic-island / dark](02-iphone/iphone-native-dynamic-island-dark-1024x1536.png) — [exact prompt](prompts-used/iphone-native-dynamic-island-dark-1024x1536-attempt-2.md)
- [today / overview / light](02-iphone/iphone-today-overview-light-1024x1536.png) — [exact prompt](prompts-used/iphone-today-overview-light-1024x1536-attempt-2.md)
- [conversation / speaking / light](02-iphone/iphone-conversation-speaking-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-speaking-light-1024x1536-attempt-2.md)
- [correction / detail / light](02-iphone/iphone-correction-detail-light-1024x1536.png) — [exact prompt](prompts-used/iphone-correction-detail-light-1024x1536-attempt-2.md)
- [conversations / list / light](02-iphone/iphone-conversations-list-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversations-list-light-1024x1536-attempt-2.md)
- [new-session / form / light](02-iphone/iphone-new-session-form-light-1024x1536.png) — [exact prompt](prompts-used/iphone-new-session-form-light-1024x1536-attempt-2.md)
- [hints / phrases / light](02-iphone/iphone-hints-phrases-light-1024x1536.png) — [exact prompt](prompts-used/iphone-hints-phrases-light-1024x1536-attempt-2.md)
- [recap / complete / light](02-iphone/iphone-recap-complete-light-1024x1536.png) — [exact prompt](prompts-used/iphone-recap-complete-light-1024x1536-attempt-2.md)
- [sign-in / github / light](02-iphone/iphone-sign-in-github-light-1024x1536.png) — [exact prompt](prompts-used/iphone-sign-in-github-light-1024x1536-attempt-2.md)
- [onboarding / microphone / light](02-iphone/iphone-onboarding-microphone-light-1024x1536.png) — [exact prompt](prompts-used/iphone-onboarding-microphone-light-1024x1536-attempt-2.md)
- [settings / resources / light](02-iphone/iphone-settings-resources-light-1024x1536.png) — [exact prompt](prompts-used/iphone-settings-resources-light-1024x1536-attempt-2.md)
- [conversation / idle / light](02-iphone/iphone-conversation-idle-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-idle-light-1024x1536-attempt-2.md)
- [conversation / recording / light](02-iphone/iphone-conversation-recording-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-recording-light-1024x1536-attempt-2.md)
- [conversation / listening / light](02-iphone/iphone-conversation-listening-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-listening-light-1024x1536-attempt-2.md)
- [conversation / thinking / light](02-iphone/iphone-conversation-thinking-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-thinking-light-1024x1536-attempt-2.md)
- [conversation / paused / light](02-iphone/iphone-conversation-paused-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-paused-light-1024x1536-attempt-2.md)
- [conversation / offline / light](02-iphone/iphone-conversation-offline-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-offline-light-1024x1536-attempt-2.md)
- [conversation / limit / light](02-iphone/iphone-conversation-limit-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-limit-light-1024x1536-attempt-2.md)
- [conversation / language-and-interruption / light](02-iphone/iphone-conversation-language-and-interruption-light-1024x1536.png) — [exact prompt](prompts-used/iphone-conversation-language-and-interruption-light-1024x1536-attempt-2.md)
- [dictionary / starred / light](02-iphone/iphone-dictionary-starred-light-1024x1536.png) — [exact prompt](prompts-used/iphone-dictionary-starred-light-1024x1536-attempt-2.md)
- [account / devices / light](02-iphone/iphone-account-devices-light-1024x1536.png) — [exact prompt](prompts-used/iphone-account-devices-light-1024x1536-attempt-2.md)
- [account / mac-connection / light](02-iphone/iphone-account-mac-connection-light-1024x1536.png) — [exact prompt](prompts-used/iphone-account-mac-connection-light-1024x1536-attempt-2.md)
- [data / export-delete / light](02-iphone/iphone-data-export-delete-light-1024x1536.png) — [exact prompt](prompts-used/iphone-data-export-delete-light-1024x1536-attempt-2.md)
- [native / locked-screen / light](02-iphone/iphone-native-locked-screen-light-1024x1536.png) — [exact prompt](prompts-used/iphone-native-locked-screen-light-1024x1536-attempt-2.md)
- [native / dynamic-island / light](02-iphone/iphone-native-dynamic-island-light-1024x1536.png) — [exact prompt](prompts-used/iphone-native-dynamic-island-light-1024x1536-attempt-3.md)

### ipad

- [conversation / landscape / dark](03-ipad/ipad-conversation-landscape-dark-1536x1024.png) — [exact prompt](prompts-used/ipad-conversation-landscape-dark-1536x1024.md)
- [conversation / portrait / dark](03-ipad/ipad-conversation-portrait-dark-1024x1536.png) — [exact prompt](prompts-used/ipad-conversation-portrait-dark-1024x1536.md)
- [conversation / landscape / light](03-ipad/ipad-conversation-landscape-light-1536x1024.png) — [exact prompt](prompts-used/ipad-conversation-landscape-light-1536x1024-attempt-2.md)
- [conversation / portrait / light](03-ipad/ipad-conversation-portrait-light-1024x1536.png) — [exact prompt](prompts-used/ipad-conversation-portrait-light-1024x1536-attempt-2.md)

### web

- [conversation / desktop / dark](05-web-desktop/web-conversation-desktop-dark-1536x1024.png) — [exact prompt](prompts-used/web-conversation-desktop-dark-1536x1024.md)
- [conversation / desktop / light](05-web-desktop/web-conversation-desktop-light-1536x1024.png) — [exact prompt](prompts-used/web-conversation-desktop-light-1536x1024-attempt-2.md)

### windows

- [conversation / chrome / dark](06-android-windows/windows-conversation-chrome-dark-1536x1024.png) — [exact prompt](prompts-used/windows-conversation-chrome-dark-1536x1024.md)
- [conversation / chrome / light](06-android-windows/windows-conversation-chrome-light-1536x1024.png) — [exact prompt](prompts-used/windows-conversation-chrome-light-1536x1024-attempt-2.md)

### android

- [conversation / chrome / dark](06-android-windows/android-conversation-chrome-dark-1024x1536.png) — [exact prompt](prompts-used/android-conversation-chrome-dark-1024x1536.md)
- [conversation / chrome / light](06-android-windows/android-conversation-chrome-light-1024x1536.png) — [exact prompt](prompts-used/android-conversation-chrome-light-1024x1536-attempt-2.md)

### teacher

- [f1 / concept / dark](07-teacher/teacher-f1-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f1-concept-dark-1024x1536.md)
- [f2 / concept / dark](07-teacher/teacher-f2-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f2-concept-dark-1024x1536.md)
- [f3 / concept / dark](07-teacher/teacher-f3-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f3-concept-dark-1024x1536-attempt-2.md)
- [f4 / concept / dark](07-teacher/teacher-f4-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f4-concept-dark-1024x1536.md)
- [f5 / concept / dark](07-teacher/teacher-f5-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f5-concept-dark-1024x1536.md)
- [f6 / concept / dark](07-teacher/teacher-f6-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f6-concept-dark-1024x1536.md)
- [f7 / concept / dark](07-teacher/teacher-f7-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f7-concept-dark-1024x1536-attempt-2.md)
- [f8 / concept / dark](07-teacher/teacher-f8-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f8-concept-dark-1024x1536.md)
- [f9 / concept / dark](07-teacher/teacher-f9-concept-dark-1024x1536.png) — [exact prompt](prompts-used/teacher-f9-concept-dark-1024x1536.md)
- [f10 / concept / dark](07-teacher/teacher-f10-concept-dark-1536x1024.png) — [exact prompt](prompts-used/teacher-f10-concept-dark-1536x1024.md)
- [f1 / concept / light](07-teacher/teacher-f1-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f1-concept-light-1024x1536-attempt-2.md)
- [f2 / concept / light](07-teacher/teacher-f2-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f2-concept-light-1024x1536-attempt-2.md)
- [f3 / concept / light](07-teacher/teacher-f3-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f3-concept-light-1024x1536-attempt-2.md)
- [f4 / concept / light](07-teacher/teacher-f4-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f4-concept-light-1024x1536-attempt-2.md)
- [f5 / concept / light](07-teacher/teacher-f5-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f5-concept-light-1024x1536-attempt-2.md)
- [f6 / concept / light](07-teacher/teacher-f6-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f6-concept-light-1024x1536-attempt-2.md)
- [f7 / concept / light](07-teacher/teacher-f7-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f7-concept-light-1024x1536.md)
- [f8 / concept / light](07-teacher/teacher-f8-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f8-concept-light-1024x1536.md)
- [f9 / concept / light](07-teacher/teacher-f9-concept-light-1024x1536.png) — [exact prompt](prompts-used/teacher-f9-concept-light-1024x1536.md)
- [f10 / concept / light](07-teacher/teacher-f10-concept-light-1536x1024.png) — [exact prompt](prompts-used/teacher-f10-concept-light-1536x1024.md)

### system

- [typography / scale / dark](08-design-system/system-typography-scale-dark-1536x1024.png) — [exact prompt](prompts-used/system-typography-scale-dark-1536x1024.md)
- [components / library / dark](08-design-system/system-components-library-dark-1536x1024.png) — [exact prompt](prompts-used/system-components-library-dark-1536x1024.md)
- [icon / app / dark](08-design-system/system-icon-app-dark-1024x1024.png) — [exact prompt](prompts-used/system-icon-app-dark-1024x1024.md)
- [typography / scale / light](08-design-system/system-typography-scale-light-1536x1024.png) — [exact prompt](prompts-used/system-typography-scale-light-1536x1024.md)
- [components / library / light](08-design-system/system-components-library-light-1536x1024.png) — [exact prompt](prompts-used/system-components-library-light-1536x1024.md)
- [icon / app / light](08-design-system/system-icon-app-light-1024x1024.png) — [exact prompt](prompts-used/system-icon-app-light-1024x1024.md)
- [palette / sheet / dark](08-design-system/system-palette-sheet-dark-1536x1024.png) — [exact prompt](prompts-used/system-palette-sheet-dark-1536x1024-attempt-2.md)
- [mark / sheet / dark](08-design-system/system-mark-sheet-dark-1024x1024.png) — [exact prompt](prompts-used/system-mark-sheet-dark-1024x1024.md)

### architecture

- [system-context / planned / dark](09-architecture/architecture-system-context-planned-dark-1536x1024.png) — [exact prompt](prompts-used/architecture-system-context-planned-dark-1536x1024.md)
- [system-context / planned / light](09-architecture/architecture-system-context-planned-light-1536x1024.png) — [exact prompt](prompts-used/architecture-system-context-planned-light-1536x1024.md)
- [voice-turn / planned / dark](09-architecture/architecture-voice-turn-planned-dark-1536x1024.png) — [exact prompt](prompts-used/architecture-voice-turn-planned-dark-1536x1024.md)
- [voice-turn / planned / light](09-architecture/architecture-voice-turn-planned-light-1536x1024.png) — [exact prompt](prompts-used/architecture-voice-turn-planned-light-1536x1024.md)
- [history-sync / planned / dark](09-architecture/architecture-history-sync-planned-dark-1536x1024.png) — [exact prompt](prompts-used/architecture-history-sync-planned-dark-1536x1024.md)
- [history-sync / planned / light](09-architecture/architecture-history-sync-planned-light-1536x1024.png) — [exact prompt](prompts-used/architecture-history-sync-planned-light-1536x1024.md)
