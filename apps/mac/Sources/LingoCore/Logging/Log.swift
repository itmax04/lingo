import os

/// Logs — R-49: `os_log`, subsystem `com.itmax04.lingo`.
/// Utterance and reply texts are never logged — only events, metrics, identifiers and errors.
/// Modelled on Interview Copilot (`Sources/CopilotCore/Logging/Log.swift`, commit cf0e764).
public enum Log {
    public static let subsystem = "com.itmax04.lingo"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let journal = Logger(subsystem: subsystem, category: "journal")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let llm = Logger(subsystem: subsystem, category: "llm")
    public static let speech = Logger(subsystem: subsystem, category: "speech")
    public static let turns = Logger(subsystem: subsystem, category: "turns")
    public static let metrics = Logger(subsystem: subsystem, category: "metrics")
}
