// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PangyoBus",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PangyoBusKit", targets: ["PangyoBusKit"]),
        .executable(name: "PangyoBus", targets: ["PangyoBus"]),
        .executable(name: "PangyoBusTests", targets: ["PangyoBusTests"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PangyoBusKit",
            dependencies: [],
            path: "Sources/PangyoBusKit"
        ),
        .executableTarget(
            name: "PangyoBus",
            dependencies: ["PangyoBusKit"],
            path: "Sources/PangyoBus"
        ),
        .executableTarget(
            name: "PangyoBusTests",
            dependencies: ["PangyoBusKit"],
            path: "Tests/PangyoBusTests"
        )
    ]
)
