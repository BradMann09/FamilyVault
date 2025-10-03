import Foundation

public enum VaultRole: String, Codable, Sendable, CaseIterable {
    case owner
    case admin
    case member
    case legacyContact
}

public struct UserProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var email: String
    public var keyReference: SecureKeyReference

    public init(id: UUID = UUID(), name: String, email: String, keyReference: SecureKeyReference) {
        self.id = id
        self.name = name
        self.email = email
        self.keyReference = keyReference
    }
}

public struct SecureKeyReference: Codable, Sendable, Hashable {
    public let identifier: String
    public let createdAt: Date
    public init(identifier: String, createdAt: Date = .now) {
        self.identifier = identifier
        self.createdAt = createdAt
    }
}

public struct Vault: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var members: [Member]
    public var policy: AccessPolicy
    public var vaultKeyRef: SecureKeyReference

    public init(id: UUID = UUID(), name: String, members: [Member], policy: AccessPolicy, vaultKeyRef: SecureKeyReference) {
        self.id = id
        self.name = name
        self.members = members
        self.policy = policy
        self.vaultKeyRef = vaultKeyRef
    }
}

public struct Member: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var profile: UserProfile
    public var role: VaultRole
    public var lastSeen: Date?

    public init(id: UUID = UUID(), profile: UserProfile, role: VaultRole, lastSeen: Date? = nil) {
        self.id = id
        self.profile = profile
        self.role = role
        self.lastSeen = lastSeen
    }
}

public enum VaultItemType: String, Codable, Sendable {
    case document
    case photo
    case video
    case note
}

public struct VaultItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let vaultId: UUID
    public var type: VaultItemType
    public var encryptedBlobReference: String
    public var tags: [String]
    public var thumbnailReference: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: VaultItemMetadata

    public init(
        id: UUID = UUID(),
        vaultId: UUID,
        type: VaultItemType,
        encryptedBlobReference: String,
        tags: [String] = [],
        thumbnailReference: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadata: VaultItemMetadata
    ) {
        self.id = id
        self.vaultId = vaultId
        self.type = type
        self.encryptedBlobReference = encryptedBlobReference
        self.tags = tags
        self.thumbnailReference = thumbnailReference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public struct VaultItemMetadata: Codable, Sendable, Hashable {
    public var titleHint: String
    public var redactedAttributes: [String: String]
    public var expiresAt: Date?
    public var checklistCategory: VitalCategory?

    public init(titleHint: String, redactedAttributes: [String: String] = [:], expiresAt: Date? = nil, checklistCategory: VitalCategory? = nil) {
        self.titleHint = titleHint
        self.redactedAttributes = redactedAttributes
        self.expiresAt = expiresAt
        self.checklistCategory = checklistCategory
    }
}

public struct AccessPolicy: Codable, Sendable, Hashable {
    public var sharingRules: [VaultRole: SharingRule]
    public var legacyRules: LegacyRule
    public var panicLockEnabled: Bool

    public init(sharingRules: [VaultRole: SharingRule], legacyRules: LegacyRule, panicLockEnabled: Bool = true) {
        self.sharingRules = sharingRules
        self.legacyRules = legacyRules
        self.panicLockEnabled = panicLockEnabled
    }
}

public struct SharingRule: Codable, Sendable, Hashable {
    public var canView: Bool
    public var canUpload: Bool
    public var canManageMembers: Bool
}

public struct LegacyRule: Codable, Sendable, Hashable {
    public var timeLockInterval: TimeInterval
    public var requiredConfirmations: Int
    public var backupContacts: [UUID]
}

public enum VitalStatus: String, Codable, Sendable {
    case missing
    case present
    case expiringSoon
    case expired
}

public enum VitalCategory: String, Codable, Sendable, CaseIterable {
    case identity
    case legal
    case insurance
    case finance
    case medical
    case emergency
    case other
}

public struct VitalChecklistItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var category: VitalCategory
    public var status: VitalStatus
    public var dueDate: Date?
    public var vaultItemId: UUID?

    public init(id: UUID = UUID(), title: String, category: VitalCategory, status: VitalStatus = .missing, dueDate: Date? = nil, vaultItemId: UUID? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.status = status
        self.dueDate = dueDate
        self.vaultItemId = vaultItemId
    }
}

public struct AuditEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let actorId: UUID
    public let action: AuditAction
    public let targetId: UUID
    public let timestamp: Date
    public var metadata: [String: String]

    public init(id: UUID = UUID(), actorId: UUID, action: AuditAction, targetId: UUID, timestamp: Date = .now, metadata: [String: String] = [:]) {
        self.id = id
        self.actorId = actorId
        self.action = action
        self.targetId = targetId
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public enum AuditAction: String, Codable, Sendable {
    case vaultCreated
    case vaultUpdated
    case itemUploaded
    case itemDecrypted
    case checklistCompleted
    case legacyUnlocked
    case panicLockEngaged
    case panicLockDisengaged
}
