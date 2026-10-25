import Foundation
import LingoCore

// CLI для evals (plan.md P-02+). Подкоманды добавляются по шагам.
//   sync-write --device <id> --session <id> --count N [--folder <папка>] [--offline] [--base <папка>]
//       второе «устройство» для S-19 без iPhone: пишет N синтетических сообщений в свой журнал;
//       без --offline сначала читает папку (сессия, lamport), после записи — пишет свой журнал в папку.
//   sync-now --device <id> --folder <папка> [--base <папка>]   записать и прочитать папку (появление сети)
//   sync-view --base <папка>                                    сообщения по сессиям в порядке R-37 (JSON)

func usage() -> Never {
    print("""
    usage: lingo-eval <command> [options]
      sync-write --device <id> --session <id> --count N [--folder <dir>] [--offline] [--base <dir>]
      sync-now   --device <id> --folder <dir> [--base <dir>]
      sync-view  --base <dir>
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
        // Синтетический текст, без личных данных (evals/README.md).
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
default:
    usage()
}
