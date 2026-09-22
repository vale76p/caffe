// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Caffe",
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
        .testTarget(
            name: "CaffeTests",
            dependencies: ["CaffeCore"],
            path: "Tests/CaffeTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
