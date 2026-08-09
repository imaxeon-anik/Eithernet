// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Eithernet",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Eithernet",
            path: "Sources/Eithernet",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation")
            ]
        )
    ]
)
