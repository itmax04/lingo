// swift-tools-version:6.2
import PackageDescription

// Стек и разрешённые зависимости — docs/decisions/ADR-0001-stack.md (п. 2, 11).
// LingoCore собирается для macOS и iOS (scripts/check-core-ios.sh); платформенный код Mac — только в LingoMac.
let package = Package(
    name: "Lingo",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .library(name: "LingoCore", targets: ["LingoCore"]),
        .executable(name: "Lingo", targets: ["LingoMac"]),
        .executable(name: "lingo-eval", targets: ["lingo-eval"]),
    ],
    dependencies: [
        // YAML для наборов evals (ADR-0001 п. 11) — только в lingo-eval.
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        // whisper.cpp — готовый XCFramework из релизов (ADR-0001 п. 6, 11); SHA256 = сумма архива из GitHub Releases (P-00).
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip",
            checksum: "e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b"
        ),
        .target(name: "LingoCore", dependencies: ["whisper"]),
        .executableTarget(
            name: "LingoMac",
            dependencies: ["LingoCore"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(
            name: "lingo-eval",
            dependencies: ["LingoCore", .product(name: "Yams", package: "Yams")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"])]
        ),
        .testTarget(name: "LingoCoreTests", dependencies: ["LingoCore"], exclude: ["Snapshots"]),
    ]
)
