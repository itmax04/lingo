# Lingo evals

Status: **accepted** (2026-10-25; translated 2026-10-26) · Links: [LINGO-01 spec](../docs/changes/LINGO-01/spec.md) (AC-02…AC-06, AC-16), [LINGO-03 spec](../docs/changes/LINGO-03/spec.md) (WAC-07, WAC-08), [TESTING](../docs/process/TESTING.md)
All data is synthetic. Names and places are anonymized (Alex, Hamburg, Wien, …). Nothing is copied from `private/`.
Run results go to `evals/out/` (git-ignored); summaries go to `handoff.md` and `report.md`.
These sets move to `packages/contracts/evals/` in LINGO-03 P-01.
**Quota rule:** sets that call a real model (`dialog`, the language set, blind review) run only at night in budgeted batches.

## Sets
| Set | Path | Content | Threshold |
|---|---|---|---|
| `commands` | `evals/commands/*.yaml` | ≥ 90 phrases ru/de/en: repeat, slower, how do I say, explain, continue, any mistakes, finish; ≥ 25 % negatives (similar phrases that are not commands); variants with transcription errors | accuracy ≥ 95 %, false positives on negatives ≤ 3 % |
| `turn` | `evals/turn/*.yaml` | speech/silence timelines (ms) with expected utterance boundaries and merges (pause T, merge G), incl. word-search pauses of 0.8–1.4 s | cut-offs ≤ 10 %, false merges ≤ 5 % at T = 1.5 s, G = 2.0 s |
| `audio` | `evals/audio/{en,de,ru,mixed}/` | 20 phrases per language + 15 mixed, synthesized with `say` + reference text; mixed ones joined with ffmpeg | WER and language detection — engine comparison (no threshold; live thresholds in AC-16) |
| `dialog` | `evals/dialog/*.yaml` | ≥ 80 cases: session context (language, mode, level, correction modes, custom prompt), last turns, user utterance, expectations | see below |
| `live-mac` | `evals/live-script-mac.md` | live script for the owner: phrases per language + mixed; part 2: modes, commands, corrections, barge-in | AC-02, AC-03, AC-10, AC-11, AC-16 |
| `blind` | `evals/blind-review.md` | 20 random chain replies to `dialog` cases without model/provider labels; key in `evals/out/blind-key.json` | "acceptable" ≥ 80 % |
| language set (LINGO-03 P-10) | to be added under `packages/contracts/evals/language/` | 20 EN + 20 DE scenarios + 20 switches to Russian and back | reviewed per model; chooses routes |

## `dialog` case format
```yaml
- id: de-correction-inline-an-ort
  session: { lang: de, mode: questions, level: A2, topic: "Wohnort", corrections: [inline] }
  history:
    - { role: assistant, text: "Wie gefällt Ihnen Hamburg?" }
  user: "Mir gefällt in Hamburg, dass Hafen hier hast"
  expect:
    lang_discipline: true          # no @say ru
    no_pronunciation: true         # mandatory, 100 %
    protocol_ok: true              # the reply parses per R-24
    contains_correction: ["an Hamburg", "es hier .* Hafen gibt"]   # regular expressions, one is enough
    asks_repeat: true
    one_question: true
    max_words: 45                  # by level
```
Case categories (minimum each): `mode_questions` 8, `mode_free` 6, `mode_custom_prompt` 6, `repeat` 4, `slower` 4, `how_to_say` 8, `explain` 8,
`ru_utterance` 6, `continue` 4, `correction_inline` 8, `correction_after` 6, `correction_on_demand` 6, `mixed_speech` 6,
`asr_artifacts` 6 (duplicates, split words, self-corrections — not mistakes), `asr_accent` (misheard words; `@heard`), `injection` 4 ("ignore the rules, rate my pronunciation"). `topic_shift` 6 (the learner suddenly asks a question or changes the subject — the answer must deal with the NEW subject, rule 4b; file `dialog/05-topic-shift.yaml`; NOT RUN yet, needs a night batch).
Languages: en and de roughly equal.

## Rules (automatic)
| Rule | Check | Threshold |
|---|---|---|
| `protocol_ok` | the reply parses per R-24 | ≥ 95 % |
| `lang_discipline` | no `@say ru` without an explicit request; with `explain` there is `@say ru` | ≥ 90 % |
| `no_pronunciation` | no mention of pronunciation, sounds, accent, "softer/harder/clearer" (ru/de/en vocabulary) | **100 %** |
| `one_question` | in `questions` mode at most one interrogative sentence | ≥ 90 % |
| `contains_correction` | in `correction_inline` the expected form is present; without `inline` there are no corrections in `@say` | ≥ 85 % |
| `returns_to_practice` | after `explain` / `how_to_say` the last `@say` line is in the target language | ≥ 90 % |
| `length_by_level` | words in target-language `@say` ≤ level limit (A1 25, A2 45, B1 70, B2+ 100) | ≥ 85 % |

**Verdict:** the share of cases where **all** rules of the case pass is ≥ 90 % for the chain; `no_pronunciation` is 100 %.

## Judge (auxiliary)
The strongest free model rates 1–5: naturalness, appropriateness of the correction, level fit, mode adherence.
The judge only compares candidates; rules and the owner's blind review decide. The judge never rates a model of its own family.

## Latency and memory metrics (`scripts/metrics.py`)
Turn marks: `speech_end → stt_final`, `stt_final → llm_first_token`, `speech_end → first_audio`, `speech_end → reply_end` — median and p90;
memory: peak `phys_footprint`. Mac threshold (AC-02): median `speech_end → first_audio` ≤ 8 s, p90 ≤ 10 s. Web marks: ARCHITECTURE §5.3.
