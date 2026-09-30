// swift-tools-version: 5.7
import PackageDescription
let package = Package(name: "OrderCore", platforms: [.iOS(.v15), .macOS(.v12)], products: [.library(name: "OrderCore", targets: ["OrderCore"])], targets: [.target(name: "OrderCore", path: "Sources/Core"), .testTarget(name: "OrderCoreTests", dependencies: ["OrderCore"], path: "Tests/Core")])
