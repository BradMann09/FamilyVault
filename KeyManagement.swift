import Foundation
import CryptoKit
import CoreKit

public protocol KeyManagement: Sendable {
    func generateVaultKey() throws -> SymmetricKey
    func wrap(key: SymmetricKey, for member: UserProfile) throws -> Data
    func unwrapKey(for member: UserProfile, encryptedKey: Data) throws -> SymmetricKey
}

public final class SecureEnclaveKeyManager: KeyManagement {
    private let enclave = SecureEnclaveProvider()
    private let storage: KeyPersistence

    public init(storage: KeyPersistence = InMemoryKeyStore()) {
        self.storage = storage
    }

    public func generateVaultKey() throws -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    public func wrap(key: SymmetricKey, for member: UserProfile) throws -> Data {
        let memberKey = try enclave.privateKey(for: member.keyReference.identifier)
        let sharedSecret = try memberKey.sharedSecretFromKeyAgreement(with: memberKey.publicKey)
        let sealBox = try AES.GCM.seal(key.withUnsafeBytes { Data($0) }, using: sharedSecret.symmetricKey)
        try storage.storeWrappedKey(sealBox.combined ?? Data(), for: member.keyReference.identifier)
        return sealBox.combined ?? Data()
    }

    public func unwrapKey(for member: UserProfile, encryptedKey: Data) throws -> SymmetricKey {
        let privateKey = try enclave.privateKey(for: member.keyReference.identifier)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: privateKey.publicKey)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedKey)
        let data = try AES.GCM.open(sealedBox, using: sharedSecret.symmetricKey)
        return SymmetricKey(data: data)
    }
}

public protocol KeyPersistence: Sendable {
    func storeWrappedKey(_ data: Data, for identifier: String) throws
    func fetchWrappedKey(for identifier: String) throws -> Data
}

public final class InMemoryKeyStore: KeyPersistence {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func storeWrappedKey(_ data: Data, for identifier: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[identifier] = data
    }

    public func fetchWrappedKey(for identifier: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let data = storage[identifier] else {
            throw AppError.keyDerivationFailed
        }
        return data
    }
}

public struct SecureEnclaveProvider {
    public init() {}

    public func privateKey(for identifier: String) throws -> CryptoKit.SecureEnclave.P256.KeyAgreement.PrivateKey {
        if let stored = try? KeychainHelper.loadKey(identifier: identifier) {
            return stored
        }
        let key = try CryptoKit.SecureEnclave.P256.KeyAgreement.PrivateKey()
        try KeychainHelper.storeKey(key, identifier: identifier)
        return key
    }
}

enum KeychainHelper {
    static func storeKey(_ key: CryptoKit.SecureEnclave.P256.KeyAgreement.PrivateKey, identifier: String) throws {
        let tag = identifier.data(using: .utf8) ?? Data()
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueRef as String: key as Any
        ]
        SecItemDelete(addQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.secureEnclaveUnavailable
        }
    }

    static func loadKey(identifier: String) throws -> CryptoKit.SecureEnclave.P256.KeyAgreement.PrivateKey {
        let tag = identifier.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item as? CryptoKit.SecureEnclave.P256.KeyAgreement.PrivateKey else {
            throw AppError.secureEnclaveUnavailable
        }
        return key
    }
}
