// swift-tools-version: 5.9
import PackageDescription

// Platform-independent core of the app: answer logic, odds, history, sharing.
// Foundation only, so it can be unit tested with `swift test` without a simulator.
let package = Package(
    name: "YesNoKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(name: "YesNoKit", targets: ["YesNoKit"]),
    ],
    targets: [
        .target(name: "YesNoKit"),
        .testTarget(name: "YesNoKitTests", dependencies: ["YesNoKit"]),
    ]
)
