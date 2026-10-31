import Foundation
import LingoCore
import LingoEvalKit

// CLI for evals (plan.md P-02+). Subcommands are added step by step.
//   sync-write --device <id> --session <id> --count N [--folder <dir>] [--offline] [--base <dir>]
//       a second "device" for S-19 without an iPhone: writes N synthetic messages to its own journal;
//       without --offline it first reads the folder (session, lamport), and after writing copies its journal to the folder.
//   sync-now --device <id> --folder <dir> [--base <dir>]       write and read the folder (network comes back)
//   sync-view --base <dir>                                      messages per session in R-37 order (JSON)
//   commands [--set packages/contracts/evals/commands]                             command detector (AC-04)
//   turn [--set packages/contracts/evals/turn]                                     end of utterance and merging (R-10, R-11)
//   stt --engine whisper:<model>|apple --set evals/audio        recognition: WER, language, latency, memory

func usage() -> Never {
    print("""
    usage: lingo-eval <command> [options]
      sync-write --device <id> --session <id> --count N [--folder <dir>] [--offline] [--base <dir>]
      sync-now   --device <id> --folder <dir> [--base <dir>]
      sync-view  --base <dir>
      commands   [--set packages/contracts/evals/commands]
      turn       [--set packages/contracts/evals/turn]
      stt        --engine whisper:<model.bin>|apple [--set packages/contracts/evals/audio] [--forced]
    """)
    exit(2)
}

struct Args {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    init(_ a: [String]) {
        var i = 0
        while i < a.count {
            let k = a[i]
            if k.hasPrefix("--"), i + 1 < a.count, !a[i + 1].hasPrefix("--") { values[k] = a[i + 1]; i += 2 }
            else { flags.insert(k); i += 1 }
        }
    }
    func req(_ k: String) -> String {
        guard let v = values[k] else { FileHandle.standardError.write(Data("missing \(k)\n".utf8)); usage() }
        return v
    }
}

func evalBase(device: String, _ a: Args) -> URL {
    if let b = a.values["--base"] { return URL(fileURLWithPath: b) }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/com.itmax04.lingo/eval-devices/\(device)", isDirectory: true)
}

func statusLine(_ s: SyncStatus) -> String {
    switch s {
    case .unavailable(let why): "unavailable (\(why))"
    default: s.title
    }
}

let argv = Array(CommandLine.arguments.dropFirst())
guard let cmd = argv.first else { usage() }
let a = Args(Array(argv.dropFirst()))

switch cmd {
case "sync-write":
    let device = a.req("--device"), session = a.req("--session")
    guard let count = Int(a.req("--count")), count > 0 else { usage() }
    let store = try JournalStore(base: evalBase(device: device, a), deviceName: "lingo-eval", deviceID: device)
    let folder = a.values["--folder"].map { SyncFolder(picked: URL(fileURLWithPath: $0)) }
    if let f = folder, !a.flags.contains("--offline") {
        print("pull: \(statusLine(await store.sync(with: f)))")
    }
    for i in 1...count {
        // Synthetic text, no personal data (evals/README.md).
        try await store.append(EventType.messageCreated, session: session,
                               Payload.MessageCreated(role: .user, text: "Testnachricht \(device) #\(i)", lang: .de))
    }
    let n = await store.state.messages[session]?.count ?? 0
    print("wrote \(count) messages as \(device); local view: \(n) messages in \(session)")
    if let f = folder, !a.flags.contains("--offline") {
        print("push: \(statusLine(await store.sync(with: f)))")
    }
case "sync-now":
    let device = a.req("--device")
    let store = try JournalStore(base: evalBase(device: device, a), deviceName: "lingo-eval", deviceID: device)
    print(statusLine(await store.sync(with: SyncFolder(picked: URL(fileURLWithPath: a.req("--folder"))))))
case "sync-view":
    let base = URL(fileURLWithPath: a.req("--base"))
    let store = try JournalStore(base: base, deviceName: "lingo-eval")
    let st = await store.state
    var out: [String: [String]] = [:]
    for (s, list) in st.messages { out[s] = list.map(\.id) }
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys, .prettyPrinted]
    print(String(decoding: try enc.encode(out), as: UTF8.self))
case "model-install":
    // Clone from the IC models folder or download from Hugging Face + SHA256 (D-02).
    let store = ModelStore.macDefault
    for m in WhisperModel.catalog where a.values["--model"] == nil || a.values["--model"] == m.file {
        let t = Date()
        let p = try await store.ensure(m)
        print(String(format: "%@ → %@ (%.1f s)", m.file, p.path, Date().timeIntervalSince(t)))
    }
case "stt-bench":
    let files = (a.values["--files"] ?? "").split(separator: ",").map(String.init)
    exit(try STTBench.run(model: a.req("--model"), files: files, gpu: !a.flags.contains("--cpu"), reduced: a.flags.contains("--reduced"),
                          threads: Int32(a.values["--threads"] ?? "4") ?? 4, minCtx: Int(a.values["--min-ctx"] ?? "64") ?? 64,
                          strategy: a.values["--strategy"], context: a.values["--context"]))
case "chunk-debug":
    exit(try ChunkDebug.run(files: (a.values["--files"] ?? "").split(separator: ",").map(String.init)))
case "tts-bench":
    exit(TTSBench.run())
case "blind":
    let from = (a.values["--from"] ?? "").split(separator: ",").map(String.init)
    exit(try BlindReview.run(from: from, cases: a.values["--cases"] ?? "packages/contracts/evals/dialog", n: Int(a.values["--n"] ?? "20") ?? 20,
                             seed: UInt64(a.values["--seed"] ?? "2026") ?? 2026))
case "dialog-recheck":
    // Recompute rules from saved replies (offline): lingo-eval dialog-recheck --from run1/dialog-x.json[,…]
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    let cases = Dictionary(uniqueKeysWithValues: try DialogCase.load(dir: URL(fileURLWithPath: a.values["--cases"] ?? "packages/contracts/evals/dialog")).map { ($0.id, $0) })
    for p in (a.values["--from"] ?? "").split(separator: ",") {
        var r = try dec.decode(DialogRunner.Report.self, from: Data(contentsOf: URL(fileURLWithPath: String(p))))
        r.rows = r.rows.map { row in
            var x = row
            if x.error == nil, let c = cases[x.id] { x.result = DialogRules.check(c, response: x.response) }
            return x
        }
        let re = DialogRunner.summarize(r.rows, model: r.model + " (recheck)", provider: r.provider)
        DialogRunner.verdict(re).lines.forEach { print($0) }
        print("  categories: " + re.categoryRates.sorted { $0.key < $1.key }.map { "\($0.key) \(Int(($0.value * 100).rounded()))%" }.joined(separator: ", "))
    }
case "dialog-report":
    // Summary of saved runs (offline): lingo-eval dialog-report --from a.json,b.json
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    for p in (a.values["--from"] ?? "").split(separator: ",") {
        let r = try dec.decode(DialogRunner.Report.self, from: Data(contentsOf: URL(fileURLWithPath: String(p))))
        DialogRunner.verdict(r).lines.forEach { print($0) }
        print("  categories: " + r.categoryRates.sorted { $0.key < $1.key }.map { "\($0.key) \(Int(($0.value * 100).rounded()))%" }.joined(separator: ", "))
    }
case "commands":
    exit(try CommandsEval.run(set: a.values["--set"] ?? "packages/contracts/evals/commands"))
case "turn":
    exit(try TurnEval.run(set: a.values["--set"] ?? "packages/contracts/evals/turn"))
case "stt":
    exit(try await STTEval.run(engine: a.req("--engine"), set: a.values["--set"] ?? "packages/contracts/evals/audio", forcedMixed: a.flags.contains("--forced")))
default:
    usage()
}
