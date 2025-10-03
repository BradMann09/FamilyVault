# FamilyVault

FamilyVault is a modular SwiftUI iOS application scaffold that provides a secure, encrypted repository for critical family documents. It targets iOS 17+ and Swift 5.9+ and is structured entirely with Swift Package Manager modules.

## Modules
- **FamilyVaultApp** – App entry point, navigation, dependency wiring.
- **CoreKit** – Shared models, errors, and logging utilities.
- **CryptoKitPlus** – Key management and envelope sealing built on CryptoKit.
- **StorageKit** – Offline-first storage providers with CloudKit stubs and local persistence.
- **VaultKit** – Vault domain services (encryption, policies, legacy flows).
- **VitalKit** – Vital checklist management, heuristics, and reminder engine.
- **AssistantKit** – On-device assistant engine and tool routing.
- **ScannerKit** – Document scanning + OCR pipeline scaffolding.
- **UIComponents** – Reusable SwiftUI design system primitives.
- **Features** – SwiftUI feature modules (Home, Upload, Assistant, etc.).

## Highlights
- End-to-end encryption scaffolding using CryptoKit and Secure Enclave keys.
- Offline-first storage with local persistence and CloudKit placeholders.
- Role-based vault policies plus legacy access confirmation flow.
- Modular assistant with on-device provider, proactive suggestions, and feature deep links.
- Vital checklist with OCR-driven classification, expiry detection, and reminders.
- 20+ unit tests covering crypto, storage, assistant, and domain logic.

## Getting Started
Open the package in Xcode 15+ and select the `FamilyVaultApp` scheme. The SwiftPM package already contains an executable target configured with a SwiftUI `App` entry. Run tests with `swift test` or from Xcode's Test navigator.

## Next Steps
- Bridge the CloudKit provider to real container identifiers and record zones.
- Replace stubs with production document scanner/OCR integrations.
- Persist assistant semantic search index and integrate with Core Spotlight.
- Expand UI polish, accessibility, localization, and background sync coverage.
