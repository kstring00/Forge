// swift-tools-version: 5.10
import PackageDescription

// ForgeCore holds everything that has no UI and no database:
// lens content, scoring, triage, shortfalls, and the shared enums.
// It compiles on Linux so the content and scoring tests run anywhere.
let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ForgeCore", targets: ["ForgeCore"]),
        .executable(name: "forge-lens-export", targets: ["forge-lens-export"])
    ],
    targets: [
        .target(name: "ForgeCore"),
        .executableTarget(name: "forge-lens-export", dependencies: ["ForgeCore"]),
        .testTarget(name: "ForgeCoreTests", dependencies: ["ForgeCore"])
    ]
)
