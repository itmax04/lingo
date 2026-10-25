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
    targets: [
        .target(name: "LingoCore"),
        .executableTarget(
            name: "LingoMac",
            dependencies: ["LingoCore"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(name: "lingo-eval", dependencies: ["LingoCore"]),
        .testTarget(name: "LingoCoreTests", dependencies: ["LingoCore"]),
    ]
)
