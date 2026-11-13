import Foundation

/// LINGO-09 MR-05, MR-08…MR-13: what a tone adds to the system prompt. Nothing here runs without an active tone (MR-07).
public enum TonePrompt {
    /// MR-02: a warm-up and an exam (Goethe training included) never have a tone, whatever the settings hold.
    public static func effective(_ s: SessionSettings) -> Tone? {
        guard let t = s.tone, t.isActive, s.warmupCards == nil, s.examKind == nil else { return nil }
        switch s.activity?.kind {
        case .warmup?, .exam?: return nil
        default: return t
        }
    }

    /// MR-05: one sentence per level. Used by the prompt and, later, shown under the sliders.
    public static func harshnessSentence(_ level: Int) -> String {
        switch level {
        case 1: "firm and direct, no praise padding"
        case 2: "strict, short, impatient; demands a repeat"
        case 3: "harsh: irritated, sarcastic, sharp about the answer"
        case 4: "very harsh: angry, personal jabs at effort and skill"
        case 5: "maximum: furious; with profanity on, swears"
        default: "today's friendly tutor"
        }
    }

    public static func hostilitySentence(_ level: Int) -> String {
        switch level {
        case 1: "cool and formal"
        case 2: "impatient and unhelpful"
        case 3: "hostile: dismissive, pushes back"
        case 4: "aggressive: accuses, everyday threats"
        case 5: "maximum: furious, personal insults; with profanity on, swears"
        default: "friendly partner"
        }
    }

    /// The sentence without its swearing clause: the `Swearing:` line carries the switch.
    static func promptSentence(_ s: String) -> String { s.replacingOccurrences(of: "; with profanity on, swears", with: "") }

    /// MR-06 in the prompt, compact (the whole addition must stay within the MR-08 budget).
    static let limits = "Never: violent threats; insults or contempt by nationality, ethnic origin, race, religion, sex, orientation or disability; sexual content; urging self-harm; pronunciation remarks. Aim only at real learner speech: not a technical error, empty or unintelligible transcript, silence, rule 4a."

    /// The `# Tone` block (MR-08): only the chosen levels, profanity yes or no, the MR-06 limits.
    public static func block(_ t: Tone) -> String {
        var l = ["# Tone"]
        if t.harshness >= 1 { l.append("Tutor \(t.harshness): \(promptSentence(harshnessSentence(t.harshness)))") }
        if t.hostility >= 1 { l.append("Character \(t.hostility): \(promptSentence(hostilitySentence(t.hostility)))") }
        l.append("Swearing: \(t.profanity && max(t.harshness, t.hostility) >= 5 ? "yes" : "no")")  // only at the level that names it (MR-05, MR-06)
        l.append(limits)
        return l.joined(separator: "\n")
    }

    /// First line of the prompt (MR-08): "friendly" goes, the learner's choice is stated.
    static func intro(name: String) -> String {
        "You are Lingo, a tutor in a VOICE chat with a native Russian speaker practising spoken \(name) who chose harsh practice. @say lines are spoken by text-to-speech; the learner's turns are speech-recognition transcripts."
    }

    /// The default role line is replaced when hostility ≥ 1 (MR-08); a given role stays and the tone colours it.
    static let hostileDefaultRole = "- Your role: a partner, manner as in # Tone."

    /// Rule 6, inline line for harshness ≥ 2 (MR-09): the correct form and a demand to repeat.
    static func demandsRepeat(_ t: Tone?) -> Bool { (t?.harshness ?? 0) >= 2 }
    static let demandRepeatLine = "   - INLINE is on: at most ONE correction per turn: give the correct form and demand a repeat; also one @fix line."

    /// MR-10: the judge-first rule, a new lettered rule after rule 6.
    static let judgeFirstRule = "6a. @fix lines first; blame only what they record."

    /// A combined session (MR-13): the tutor speaks in `@tutor` lines, the character in `@say` lines.
    static func isCombined(_ t: Tone) -> Bool { t.harshness >= 1 && t.hostility >= 1 }

    /// MR-11…MR-13: the extra protocol lines of a tone session (all silent but `@tutor`).
    static func protocolLines(_ t: Tone, lang: Lang, inline: Bool) -> [String] {
        let L = lang.rawValue
        var out: [String] = []
        if t.harshness >= 2, inline { out.append("@next \(L): <next question>") }
        out.append("@help: <Russian strategy> | <answer start> + @hint")
        if isCombined(t) { out.append("@tutor \(L): <correction, repeat demand>; @say = character") }
        return out
    }

    /// The protocol example of a tone session shows the judge-first order (MR-10). A combined session (MR-13) shows the correction
    /// in the tutor's `@tutor` line and the character in `@say`: `@fix` → `@tutor` → `@say`.
    static func example(_ lang: Lang, combined: Bool = false) -> String {
        switch lang {
        case .de:
            combined
                ? """
                @fix: Ich wohne hier seit zwei Jahre → Ich wohne seit zwei Jahren hier | seit + Dativ
                @tutor de: Richtig: „Ich wohne seit zwei Jahren hier.“
                @say de: Und?
                """
                : """
                @fix: Ich wohne hier seit zwei Jahre → Ich wohne seit zwei Jahren hier | seit + Dativ
                @say de: Nein. Richtig: „Ich wohne seit zwei Jahren hier.“
                """
        default:
            combined
                ? """
                @fix: I live here since two years → I have lived here for two years | for + срок
                @tutor en: Say: “I have lived here for two years.”
                @say en: And?
                """
                : """
                @fix: I live here since two years → I have lived here for two years | for + срок
                @say en: No. Say: “I have lived here for two years.”
                """
        }
    }
}
