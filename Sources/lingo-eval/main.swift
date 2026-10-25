import Foundation
import LingoCore

// CLI для evals (plan.md P-02+). Подкоманды добавляются по шагам.
let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else {
    print("usage: lingo-eval <command> [options]\ncommands: (пока нет)")
    exit(2)
}
FileHandle.standardError.write(Data("lingo-eval: unknown command \(cmd)\n".utf8))
exit(2)
