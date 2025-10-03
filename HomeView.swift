import SwiftUI
import CoreKit
import VaultKit
import VitalKit
import UIComponents

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var vaults: [Vault] = []
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var checklist: [VitalChecklistItem] = []

    private let vaultService: VaultService
    private let checklistService: VitalChecklistService

    public init(vaultService: VaultService, checklistService: VitalChecklistService) {
        self.vaultService = vaultService
        self.checklistService = checklistService
    }

    public func load() async {
        do {
            vaults = try await vaultService.listVaults()
            checklist = await checklistService.itemsList()
            progress = await checklistService.checklistProgress()
        } catch {
            progress = 0
        }
    }
}

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let onOpenVault: (Vault) -> Void
    private let onOpenChecklist: () -> Void

    public init(viewModel: @escaping () -> HomeViewModel, onOpenVault: @escaping (Vault) -> Void, onOpenChecklist: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onOpenVault = onOpenVault
        self.onOpenChecklist = onOpenChecklist
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VaultCard(title: "Vital Checklist", subtitle: "Track critical documents") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: viewModel.progress)
                        Text("\(Int(viewModel.progress * 100))% complete")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Review Checklist") {
                            onOpenChecklist()
                        }
                        .buttonStyle(VaultPrimaryButtonStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Vaults")
                        .font(.title2.weight(.semibold))
                    ForEach(viewModel.vaults) { vault in
                        Button {
                            onOpenVault(vault)
                        } label: {
                            VaultCard(title: vault.name, subtitle: "Members: \(vault.members.count)") {
                                Text("Policy confirmations: \(vault.policy.legacyRules.requiredConfirmations)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(VaultTheme.background)
        .task {
            await viewModel.load()
        }
        .navigationTitle("Family Vault")
    }
}
