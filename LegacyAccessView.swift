import SwiftUI
import CoreKit
import VaultKit

@MainActor
public final class LegacyAccessViewModel: ObservableObject {
    @Published public private(set) var state: LegacyAccessState?
    @Published public private(set) var policy: AccessPolicy
    private let vaultId: UUID
    private let manager: LegacyAccessManager
    private let member: Member

    public init(policy: AccessPolicy, vaultId: UUID, manager: LegacyAccessManager, member: Member) {
        self.policy = policy
        self.vaultId = vaultId
        self.manager = manager
        self.member = member
    }

    public func load() async {
        state = try? await manager.scheduleLegacyAccessCheck(for: vaultId)
    }

    public func confirm() async {
        state = try? await manager.confirmLegacyAccess(vaultId: vaultId, confirmer: member)
    }
}

public struct LegacyAccessView: View {
    @StateObject private var viewModel: LegacyAccessViewModel

    public init(viewModel: @escaping () -> LegacyAccessViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        Form {
            Section("Policy") {
                Text("Time-lock: \(Int(viewModel.policy.legacyRules.timeLockInterval / 3600)) hours")
                Text("Confirmations required: \(viewModel.policy.legacyRules.requiredConfirmations)")
                Text("Backup contacts: \(viewModel.policy.legacyRules.backupContacts.count)")
            }
            Section("Actions") {
                Button("Confirm Access") {
                    Task { await viewModel.confirm() }
                }
            }
            if let state = viewModel.state {
                Section("Status") {
                    Text(state.isUnlocked ? "Unlocked" : "Locked")
                    Text("Confirmations: \(state.confirmations)")
                }
            }
        }
        .task { await viewModel.load() }
        .navigationTitle("Legacy Access")
    }
}
