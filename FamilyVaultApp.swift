import SwiftUI
import CoreKit
import VaultKit
import StorageKit
import CryptoKitPlus
import VitalKit
import AssistantKit
import ScannerKit
import Features

@main
struct FamilyVaultApp: App {
    private let services = AppServices.make()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}

struct AppServices {
    let user: UserProfile
    let member: Member
    let vaultService: VaultService
    let legacyManager: LegacyAccessManager
    let checklistService: VitalChecklistService
    let reminderEngine: ReminderEngine
    let assistantEngine: AssistantEngine
    let pipeline: OCRPipeline

    static func make() -> AppServices {
        let logger = AppLogger()
        let reminderEngine = ReminderEngine()
        let checklistService = VitalChecklistService(reminderEngine: reminderEngine)
        let repository = InMemoryVaultRepository()
        let keyManager = SecureEnclaveKeyManager()
        let local = LocalOnlyStorageProvider()
        let storage = StorageCoordinator(local: local, remote: nil)
        let vaultService = VaultService(repository: repository, keyManager: keyManager, storage: storage, logger: logger)
        let legacyManager = LegacyAccessManager(repository: repository, logger: logger)

        let user = UserProfile(name: "Alex", email: "alex@familyvault.app", keyReference: SecureKeyReference(identifier: "owner-key"))
        let member = Member(profile: user, role: .owner)

        let checklistTool = ChecklistTool(reminderEngine: reminderEngine)
        let provider = OnDeviceAssistantProvider()
        let assistantEngine = AssistantEngine(provider: provider, tools: [checklistTool, VaultNavigationTool(), LegacyTool()])
        let pipeline = OCRPipeline(scanner: StubDocumentScanner(), ocr: SimpleOCRProcessor(), classifier: HeuristicVitalClassifier())

        Task {
            await bootstrap(vaultService: vaultService, member: member)
        }

        return AppServices(
            user: user,
            member: member,
            vaultService: vaultService,
            legacyManager: legacyManager,
            checklistService: checklistService,
            reminderEngine: reminderEngine,
            assistantEngine: assistantEngine,
            pipeline: pipeline
        )
    }
    private static func bootstrap(vaultService: VaultService, member: Member) async {
        let policy = AccessPolicy(
            sharingRules: [
                .owner: SharingRule(canView: true, canUpload: true, canManageMembers: true),
                .admin: SharingRule(canView: true, canUpload: true, canManageMembers: false),
                .member: SharingRule(canView: true, canUpload: false, canManageMembers: false),
                .legacyContact: SharingRule(canView: false, canUpload: false, canManageMembers: false)
            ],
            legacyRules: LegacyRule(timeLockInterval: 72 * 3600, requiredConfirmations: 2, backupContacts: [])
        )
        _ = try? await vaultService.createVault(name: "Family", owner: member, policy: policy)
    }
}

struct RootView: View {
    private let services: AppServices
    @State private var path: [Route] = []
    @State private var showingOnboarding = true
    @State private var checklistItems: [VitalChecklistItem] = []

    init(services: AppServices) {
        self.services = services
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(viewModel: {
                HomeViewModel(vaultService: services.vaultService, checklistService: services.checklistService)
            }, onOpenVault: { vault in
                path.append(.vaultDetail(vault))
            }, onOpenChecklist: {
                Task {
                    let items = await services.checklistService.itemsList()
                    await MainActor.run {
                        checklistItems = items
                        path.append(.checklist)
                    }
                }
            })
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .vaultDetail(let vault):
                    VaultDetailView {
                        VaultDetailViewModel(vault: vault, member: services.member, vaultService: services.vaultService)
                    }
                case .upload(let vault):
                    UploadFlowView(viewModel: {
                        UploadFlowViewModel(
                            vault: vault,
                            member: services.member,
                            vaultService: services.vaultService,
                            pipeline: services.pipeline,
                            checklist: services.checklistService
                        )
                    }, onFinish: {
                        path.removeAll { route in
                            if case .upload(let existing) = route {
                                return existing.id == vault.id
                            }
                            return false
                        }
                    })
                case .members(let vault):
                    MembersView(members: vault.members) {
                        // Invite flow placeholder
                    }
                case .legacy(let vault):
                    LegacyAccessView {
                        LegacyAccessViewModel(
                            policy: vault.policy,
                            vaultId: vault.id,
                            manager: services.legacyManager,
                            member: services.member
                        )
                    }
                case .assistant:
                    AssistantChatView(viewModel: {
                        AssistantChatViewModel(engine: services.assistantEngine) {
                            let vaults = (try? await services.vaultService.listVaults()) ?? []
                            let checklist = await services.checklistService.itemsList()
                            return AssistantContext(
                                user: services.user,
                                vaults: vaults,
                                checklist: checklist
                            )
                        }
                    }, onAction: { action in
                        handle(action)
                    })
                case .checklist:
                    ChecklistView(items: checklistItems) {
                        await refreshChecklist()
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if let vaults = try? await services.vaultService.listVaults(),
                               let firstVault = vaults.first {
                                path.append(.upload(firstVault))
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        path.append(.assistant)
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView {
                    showingOnboarding = false
                }
            }
        }
        .task {
            await refreshChecklist()
        }
    }

    private func handle(_ action: AssistantAction) {
        switch action {
        case .openChecklist:
            Task {
                let items = await services.checklistService.itemsList()
                await MainActor.run {
                    checklistItems = items
                    if !path.contains(.checklist) {
                        path.append(.checklist)
                    }
                }
            }
        case .openVaultItem(let id):
            Task {
                _ = id
                if let vaults = try? await services.vaultService.listVaults(), let vault = vaults.first {
                    await MainActor.run { path.append(.vaultDetail(vault)) }
                }
            }
        case .openLegacyAccess:
            Task {
                if let vault = try? await services.vaultService.listVaults().first {
                    await MainActor.run { path.append(.legacy(vault)) }
                }
            }
        case .scheduleReminder(let checklistId):
            Task {
                if let item = (await services.checklistService.itemsList()).first(where: { $0.id == checklistId }) {
                    await services.reminderEngine.scheduleReminderIfNeeded(for: item)
                }
            }
        case .openUpload:
            Task {
                if let vault = try? await services.vaultService.listVaults().first {
                    await MainActor.run { path.append(.upload(vault)) }
                }
            }
        }
    }

    private func refreshChecklist() async {
        checklistItems = await services.checklistService.itemsList()
    }
}

enum Route: Hashable {
    case vaultDetail(Vault)
    case upload(Vault)
    case members(Vault)
    case legacy(Vault)
    case assistant
    case checklist
}
