import SwiftUI
import CoreKit
import VaultKit

@MainActor
public final class VaultDetailViewModel: ObservableObject {
    @Published public private(set) var items: [VaultItem] = []
    @Published public private(set) var isLoading = false
    @Published public var alertMessage: String?

    private let vault: Vault
    private let member: Member
    private let vaultService: VaultService

    public init(vault: Vault, member: Member, vaultService: VaultService) {
        self.vault = vault
        self.member = member
        self.vaultService = vaultService
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await vaultService.items(in: vault.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    public func decrypt(item: VaultItem) async {
        do {
            _ = try await vaultService.decrypt(item: item, for: member)
            alertMessage = "Decrypted successfully"
        } catch {
            alertMessage = "Unable to decrypt"
        }
    }
}

public struct VaultDetailView: View {
    @StateObject private var viewModel: VaultDetailViewModel

    public init(viewModel: @escaping () -> VaultDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        List {
            Section("Documents") {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.metadata.titleHint)
                            .font(.headline)
                        Text(item.metadata.checklistCategory?.rawValue.capitalized ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Decrypt") {
                            Task { await viewModel.decrypt(item: item) }
                        }
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .alert(item: Binding(get: {
            viewModel.alertMessage.map { AlertWrapper(message: $0) }
        }, set: { value in
            viewModel.alertMessage = value?.message
        })) { wrapper in
            Alert(title: Text(wrapper.message))
        }
        .navigationTitle("Vault")
    }
}

private struct AlertWrapper: Identifiable {
    let message: String
    var id: String { message }
}
