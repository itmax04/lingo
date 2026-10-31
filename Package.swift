// swift-tools-version:6.2
import PackageDescription

// Stack and allowed dependencies — docs/decisions/ADR-0001-stack.md (§2, §11).
// LingoCore builds for macOS and iOS (scripts/check-core-ios.sh); Mac-only platform code lives only in LingoMac.
let package = Package(
    name: "Lingo",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .library(name: "LingoCore", targets: ["LingoCore"]),
        .executable(name: "Lingo", targets: ["LingoMac"]),
        .executable(name: "lingo-eval", targets: ["lingo-eval"]),
    ],
    dependencies: [
        // YAML for the eval sets (ADR-0001 §11) — only in lingo-eval.
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        // whisper.cpp — the prebuilt XCFramework from the releases (ADR-0001 §6, §11); SHA256 = checksum of the GitHub Releases archive (P-00).
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip",
            checksum: "e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b"
        ),
        .target(name: "LingoCore", dependencies: ["whisper"]),
        // Dialogue evals: YAML sets, rules, runner (lingo-eval and Lingo.app --eval-dialog). Not part of the iOS core.
        .target(name: "LingoEvalKit", dependencies: ["LingoCore", .product(name: "Yams", package: "Yams")]),
        .executableTarget(
            name: "LingoMac",
            dependencies: ["LingoCore", "LingoEvalKit"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(
            name: "lingo-eval",
            dependencies: ["LingoCore", "LingoEvalKit", .product(name: "Yams", package: "Yams")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"])]
        ),
        .testTarget(name: "LingoMacTests", dependencies: ["LingoMac", "LingoCore"]),
        .testTarget(name: "LingoCoreTests", dependencies: ["LingoCore", "LingoEvalKit"], exclude: ["Snapshots"]),
    ]
)
