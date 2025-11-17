// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "brewmeister",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "brewmeister", targets: ["brewmeister"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "brewmeister",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Resources/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "brewmeisterTests",
            dependencies: ["brewmeister"]
        )
    ]
)
