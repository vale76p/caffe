// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Caffe",
    platforms: [
        .macOS(.v13) // SMAppService (login item) richiede macOS 13
    ],
    targets: [
        .target(
            name: "CaffeCore",
            path: "Sources/CaffeCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Caffe",
            dependencies: ["CaffeCore"],
            path: "Sources/Caffe",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "CaffeTestRunner",
            dependencies: ["CaffeCore"],
            path: "Sources/CaffeTestRunner",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
