import Foundation
import CryptoKit
import CoreKit
import CryptoKitPlus
import StorageKit

public protocol VaultRepository: Sendable {
    func saveVault(_ vault: Vault) async throws
    func fetchVault(id: UUID) async throws -> Vault
    func listVaults() async throws -> [Vault]
    func updateVault(_ vault: Vault) async throws
}

public actor InMemoryVaultRepository: VaultRepository {
    private var storage: [UUID: Vault] = [:]

    public init() {}

    public func saveVault(_ vault: Vault) async throws {
        storage[vault.id] = vault
    }

    public func fetchVault(id: UUID) async throws -> Vault {
        guard let vault = storage[id] else { throw AppError.vaultNotFound }
        return vault
    }

    public func listVaults() async throws -> [Vault] {
        Array(storage.values)
    }

    public func updateVault(_ vault: Vault) async throws {
        storage[vault.id] = vault
    }
}

public actor VaultService {
    private let repository: VaultRepository
    private let keyManager: KeyManagement
    private let storage: StorageCoordinator
    private let sealer = EnvelopeSealer()
    private let logger: Logger

    public init(
        repository: VaultRepository,
        keyManager: KeyManagement,
        storage: StorageCoordinator,
        logger: Logger = AppLogger()
    ) {
        self.repository = repository
        self.keyManager = keyManager
        self.storage = storage
        self.logger = logger
    }

    public func createVault(name: String, owner: Member, policy: AccessPolicy) async throws -> Vault {
        let vaultKey = try keyManager.generateVaultKey()
        _ = try keyManager.wrap(key: vaultKey, for: owner.profile)
        let vault = Vault(name: name, members: [owner], policy: policy, vaultKeyRef: owner.profile.keyReference)
        try await repository.saveVault(vault)
        logger.log("Created vault \(vault.id)", category: .security)
        return vault
    }

    public func listVaults() async throws -> [Vault] {
        try await repository.listVaults()
    }

    public func invite(member: Member, to vaultId: UUID) async throws {
        var vault = try await repository.fetchVault(id: vaultId)
        guard !vault.members.contains(where: { $0.id == member.id }) else { return }
        vault.members.append(member)
        try await repository.updateVault(vault)
        logger.log("Invited member \(member.id) to vault \(vault.id)", category: .security)
    }

    public func upload(item data: Data, metadata: VaultItemMetadata, to vaultId: UUID, by member: Member) async throws -> VaultItem {
        var vault = try await repository.fetchVault(id: vaultId)
        guard vault.members.contains(where: { $0.id == member.id }) else {
            throw AppError.userNotAuthorized
        }
        let itemId = UUID()
        let symmetricKey = deriveKey(for: vault, itemId: itemId)
        let envelope = try sealer.seal(data: data, metadata: metadata.redactedAttributes, using: symmetricKey)
        let envelopeData = try JSONEncoder().encode(envelope)
        let item = VaultItem(
            id: itemId,
            vaultId: vaultId,
            type: .document,
            encryptedBlobReference: envelopeData.base64EncodedString(),
            metadata: metadata
        )
        try await storage.saveItem(item, data: envelopeData)
        try await repository.updateVault(vault)
        logger.log("Uploaded item \(item.id) to vault \(vaultId)", category: .storage)
        return item
    }

    public func items(in vaultId: UUID) async throws -> [VaultItem] {
        try await storage.listItems(in: vaultId)
    }

    public func decrypt(item: VaultItem, for member: Member) async throws -> Data {
        guard let encryptedData = Data(base64Encoded: item.encryptedBlobReference) else {
            throw AppError.decryptionFailed
        }
        let envelope = try JSONDecoder().decode(EnvelopeSealer.Envelope.self, from: encryptedData)
        let vault = try await repository.fetchVault(id: item.vaultId)
        let key = deriveKey(for: vault, itemId: item.id)
        return try sealer.open(envelope: envelope, using: key)
    }
}

public actor LegacyAccessManager {
    private let repository: VaultRepository
    private let logger: Logger

    public init(repository: VaultRepository, logger: Logger = AppLogger()) {
        self.repository = repository
        self.logger = logger
    }

    public func scheduleLegacyAccessCheck(for vaultId: UUID) async throws -> LegacyAccessState {
        let vault = try await repository.fetchVault(id: vaultId)
        return LegacyAccessState(policy: vault.policy, confirmations: 0, isUnlocked: false)
    }

    public func confirmLegacyAccess(vaultId: UUID, confirmer: Member) async throws -> LegacyAccessState {
        var vault = try await repository.fetchVault(id: vaultId)
        guard vault.policy.sharingRules[confirmer.role]?.canManageMembers == true else {
            throw AppError.userNotAuthorized
        }
        var state = LegacyAccessState(policy: vault.policy, confirmations: 1, isUnlocked: false)
        if state.confirmations >= vault.policy.legacyRules.requiredConfirmations {
            state.isUnlocked = true
            logger.log("Legacy access unlocked for vault \(vaultId)", category: .security)
        }
        return state
    }
}

public struct LegacyAccessState: Sendable {
    public var policy: AccessPolicy
    public var confirmations: Int
    public var isUnlocked: Bool
}

private extension VaultService {
    func deriveKey(for vault: Vault, itemId: UUID) -> SymmetricKey {
        let seed = vault.vaultKeyRef.identifier + itemId.uuidString
        let hash = SHA256.hash(data: Data(seed.utf8))
        return SymmetricKey(data: Data(hash))
    }
}
