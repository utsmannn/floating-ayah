// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FloatingAyah",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FloatingAyah", targets: ["FloatingAyah"])],
    targets: [
        .executableTarget(name: "FloatingAyah", resources: [.process("Resources")]),
        .testTarget(name: "FloatingAyahTests", dependencies: ["FloatingAyah"])
    ]
)
