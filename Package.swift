// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CapsLockLED",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CapsLockLED",
            path: "Sources/CapsLockLED"
        ),
        .executableTarget(
            name: "caps-signal",
            path: "Sources/caps-signal"
        )
    ]
)
