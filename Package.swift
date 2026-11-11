// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "KiwiBar", platforms: [.macOS(.v14)], products: [.executable(name: "KiwiBar", targets: ["KiwiBar"])], targets: [.target(name: "BandwagonCore"), .executableTarget(name: "KiwiBar", dependencies: ["BandwagonCore"]), .testTarget(name: "BandwagonCoreTests", dependencies: ["BandwagonCore"])])
