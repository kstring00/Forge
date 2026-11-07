// swift-tools-version: 5.10
import PackageDescription

// ForgeCore holds everything that has no UI and no database:
// lens content, scoring, triage, shortfalls, and the shared enums.
// It compiles on Linux so the content and scoring tests run anywhere.
let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ForgeCore", targets: ["ForgeCore"])
    ],
    targets: [
        .target(name: "ForgeCore"),
        .testTarget(name: "ForgeCoreTests", dependencies: ["ForgeCore"])
    ]
)
