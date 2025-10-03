// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyVault",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "FamilyVaultApp",
            targets: ["FamilyVaultApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CoreKit",
            dependencies: [],
            path: "Sources/CoreKit"
        ),
        .target(
            name: "CryptoKitPlus",
            dependencies: ["CoreKit"],
            path: "Sources/CryptoKitPlus"
        ),
        .target(
            name: "StorageKit",
            dependencies: ["CoreKit"],
            path: "Sources/StorageKit"
        ),
        .target(
            name: "VaultKit",
            dependencies: ["CoreKit", "CryptoKitPlus", "StorageKit"],
            path: "Sources/VaultKit"
        ),
        .target(
            name: "VitalKit",
            dependencies: ["CoreKit", "StorageKit"],
            path: "Sources/VitalKit"
        ),
        .target(
            name: "AssistantKit",
            dependencies: ["CoreKit", "VitalKit", "VaultKit", "StorageKit", "CryptoKitPlus"],
            path: "Sources/AssistantKit"
        ),
        .target(
            name: "ScannerKit",
            dependencies: ["CoreKit", "VitalKit"],
            path: "Sources/ScannerKit"
        ),
        .target(
            name: "UIComponents",
            dependencies: ["CoreKit"],
            path: "Sources/UIComponents"
        ),
        .target(
            name: "Features",
            dependencies: ["CoreKit", "StorageKit", "VaultKit", "VitalKit", "AssistantKit", "ScannerKit", "UIComponents"],
            path: "Sources/Features"
        ),
        .executableTarget(
            name: "FamilyVaultApp",
            dependencies: ["CoreKit", "VaultKit", "StorageKit", "VitalKit", "AssistantKit", "UIComponents", "Features"],
            path: "Sources/FamilyVaultApp"
        ),
        .testTarget(
            name: "CoreKitTests",
            dependencies: ["CoreKit"],
            path: "Tests/CoreKitTests"
        ),
        .testTarget(
            name: "CryptoKitPlusTests",
            dependencies: ["CryptoKitPlus"],
            path: "Tests/CryptoKitPlusTests"
        ),
        .testTarget(
            name: "StorageKitTests",
            dependencies: ["StorageKit"],
            path: "Tests/StorageKitTests"
        ),
        .testTarget(
            name: "VaultKitTests",
            dependencies: ["VaultKit"],
            path: "Tests/VaultKitTests"
        ),
        .testTarget(
            name: "VitalKitTests",
            dependencies: ["VitalKit"],
            path: "Tests/VitalKitTests"
        ),
        .testTarget(
            name: "AssistantKitTests",
            dependencies: ["AssistantKit"],
            path: "Tests/AssistantKitTests"
        )
    ],
    swiftLanguageVersions: [.version("5.9")]
)
