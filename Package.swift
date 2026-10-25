// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Yiyu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Yiyu", targets: ["Yiyu"]),
    ],
    targets: [
        .target(name: "YiyuCore"),
        .executableTarget(
            name: "Yiyu",
            dependencies: ["YiyuCore"],
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        .testTarget(name: "YiyuCoreTests", dependencies: ["YiyuCore"]),
    ]
)
