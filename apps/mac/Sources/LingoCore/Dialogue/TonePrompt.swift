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
    static let limits = "Never: violent threats; insults by nationality, race, religion, sex, orientation or disability; sexual content; self-harm; remarks on pronunciation. Aim only at real learner speech, never at a technical error, silence or a rule 4a case."

    /// The `# Tone` block (MR-08): only the chosen levels, profanity yes or no, the MR-06 limits.
    public static func block(_ t: Tone) -> String {
        var l = ["# Tone"]
        if t.harshness >= 1 { l.append("Tutor \(t.harshness): \(promptSentence(harshnessSentence(t.harshness)))") }
        if t.hostility >= 1 { l.append("Character \(t.hostility): \(promptSentence(hostilitySentence(t.hostility)))") }
        l.append("Swearing: \(t.profanity ? "yes" : "no")")
        l.append(limits)
        return l.joined(separator: "\n")
    }

    /// First line of the prompt (MR-08): "friendly" goes, the learner's choice is stated.
    static func intro(name: String) -> String {
        "You are Lingo, a tutor in a VOICE chat with a native Russian speaker practising spoken \(name). The learner chose harsh practice. @say lines are spoken by text-to-speech; the learner's turns are speech-recognition transcripts."
    }

    /// The default role line is replaced when hostility ≥ 1 (MR-08); a given role stays and the tone colours it.
    static let hostileDefaultRole = "- Your role: a partner, manner as in # Tone."

    /// Rule 6, inline line for harshness ≥ 2 (MR-09): the correct form and a demand to repeat.
    static func demandsRepeat(_ t: Tone?) -> Bool { (t?.harshness ?? 0) >= 2 }
    static let demandRepeatLine = "   - INLINE is on: at most ONE correction per turn: give the correct form and demand a repeat, then continue; also one @fix line."

    /// MR-10: the judge-first rule, a new lettered rule after rule 6.
    static let judgeFirstRule = "6a. Judge first: @fix lines before speech; blame only what they record."

    /// MR-11…MR-13: the extra protocol lines of a tone session (all silent but `@tutor`).
    static func protocolLines(_ t: Tone, lang: Lang, inline: Bool) -> [String] {
        let L = lang.rawValue
        var out: [String] = []
        if t.harshness >= 2, inline { out.append("@next \(L): <next question>") }
        out.append("@help: <Russian strategy> | <first words of an answer> + @hint")
        if t.harshness >= 1, t.hostility >= 1 { out.append("@tutor \(L): <tutor: correction, demand to repeat> (@say is the character)") }
        return out
    }

    /// The protocol example of a tone session shows the judge-first order (MR-10).
    static func example(_ lang: Lang) -> String {
        switch lang {
        case .de:
            """
            @fix: Ich wohne hier seit zwei Jahre → Ich wohne seit zwei Jahren hier | seit + Dativ
            @say de: Nein. Richtig: „Ich wohne seit zwei Jahren hier.“
            """
        default:
            """
            @fix: I live here since two years → I have lived here for two years | for + срок
            @say en: No. Say: “I have lived here for two years.”
            """
        }
    }
}
