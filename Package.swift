// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SKALAMenuBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SKALA-MenuBar", targets: ["SKALAMenuBar"]),
        .executable(name: "SKALAMenuBarTests", targets: ["SKALAMenuBarTests"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SKALAMenuBarKit",
            dependencies: [],
            path: "Sources/SKALAMenuBarKit"
        ),
        .executableTarget(
            name: "SKALAMenuBar",
            dependencies: ["SKALAMenuBarKit"],
            path: "Sources/SKALAMenuBar"
        ),
        .executableTarget(
            name: "SKALAMenuBarTests",
            dependencies: ["SKALAMenuBarKit"],
            path: "Tests/SKALAMenuBarTests"
        )
    ]
)
