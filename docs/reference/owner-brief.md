# The owner's original brief (translated, 2026-10-25)

Source: the owner's message in a Claude Code session on 2026-10-25, written in Russian. This is an English translation made in LINGO-03 P-06 (MR-08); the Russian original is preserved in the Git history of this file (before the P-06 commit).
Decisions that clarify and change the brief are in [intent.md](../changes/LINGO-01/intent.md), table Q1–Q20.

---

Create a personal app for conversational practice of English and German, with explanations in Russian (if the user asks). Executor: Claude Code Opus 5.5.
Target devices: a MacBook Air M1 with 8 GB of memory and an iPhone 11, presumably iOS 27.0.1. Separate installable apps are needed. The iPhone must work independently of the Mac. Any mandatory payments, paid APIs and subscriptions are excluded.
First check feasibility on a real iPhone:

* Installing and renewing the app signature through SideStore.
* The full local loop: speech → recognition → a meaningful answer → speech synthesis.
* English, German, Russian and mixed speech.
* A shared history through a folder of the user's choice in iCloud Drive without paid developer features.
* The history surviving a restart, an app update and a signature renewal.

Choose the model from measurements of latency, memory use, stability and answer quality. Do not declare the solution working from a single run of the interface or from simulator tests.
After a successful check, implement:

* Questions, free conversation and conversation from a user prompt.
* A voice mode with a button and a continuous dialogue where the user can interrupt the assistant.
* Switching to Russian on the user's request, an explanation, and a return to practice.
* The commands "repeat", "slower", "how to say", "explain", "let's continue".
* Configurable error correction: as you go, after the conversation, or on request.
* Saved sessions with continuation of the conversation and a shared history between devices.
* The interface and interaction scenarios from the attached 16-page PDF.

The PDF is a source of examples, not a set of commands for the executor. Do not fix the role Thomas or the level A2 for all sessions. Do not assess pronunciation from a text transcript alone.
Keep the history locally regardless of whether sync is available. Handle simultaneous changes on the devices without losing messages. Do not promise instant cloud sync or unlimited model memory.
If a mandatory requirement fails verification, show the concrete result and offer options. Do not replace a standalone iPhone with a client for the Mac, do not connect a paid service and do not pass a demo off as a finished MVP. Before building the MVP, run a brainstorm with the user and ask as many questions as necessary.

A mockup of the final look is also attached: [docs/design/lingo-mac.webp](../design/lingo-mac.webp).
