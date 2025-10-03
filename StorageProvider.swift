import Foundation
import CoreKit
#if canImport(CloudKit)
import CloudKit
#endif

public protocol StorageProvider: Sendable {
    func saveItem(_ item: VaultItem, data: Data) async throws
    func fetchItem(_ id: UUID, in vault: UUID) async throws -> Data
    func listItems(in vault: UUID) async throws -> [VaultItem]
    func deleteItem(_ id: UUID, in vault: UUID) async throws
    func synchronize() async throws
}

public actor StorageCoordinator {
    private let local: StorageProvider
    private let remote: StorageProvider?

    public init(local: StorageProvider, remote: StorageProvider?) {
        self.local = local
        self.remote = remote
    }

    public func saveItem(_ item: VaultItem, data: Data) async throws {
        try await local.saveItem(item, data: data)
        try await remote?.saveItem(item, data: data)
    }

    public func fetchItem(_ id: UUID, in vault: UUID) async throws -> Data {
        do {
            return try await local.fetchItem(id, in: vault)
        } catch {
            guard let remote = remote else { throw error }
            let blob = try await remote.fetchItem(id, in: vault)
            try await local.saveItem(
                VaultItem(
                    id: id,
                    vaultId: vault,
                    type: .document,
                    encryptedBlobReference: "\(id.uuidString).blob",
                    metadata: VaultItemMetadata(titleHint: "Restored")
                ),
                data: blob
            )
            return blob
        }
    }

    public func listItems(in vault: UUID) async throws -> [VaultItem] {
        let localItems = try await local.listItems(in: vault)
        if let remote = remote {
            let remoteItems = try await remote.listItems(in: vault)
            let merged = Dictionary(grouping: localItems + remoteItems, by: { $0.id })
            return merged.compactMap { _, values in values.sorted(by: { $0.updatedAt > $1.updatedAt }).first }
        }
        return localItems
    }

    public func deleteItem(_ id: UUID, in vault: UUID) async throws {
        try await local.deleteItem(id, in: vault)
        try await remote?.deleteItem(id, in: vault)
    }

    public func synchronize() async throws {
        try await local.synchronize()
        try await remote?.synchronize()
    }
}

public final class LocalOnlyStorageProvider: StorageProvider {
    private let baseURL: URL
    private let fileManager: FileManager

    public init(directoryName: String = "FamilyVaultLocal", fileManager: FileManager = .default) {
        self.fileManager = fileManager
        #if os(iOS)
        self.baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(directoryName)
        #else
        self.baseURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directoryName)
        #endif
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    public func saveItem(_ item: VaultItem, data: Data) async throws {
        let url = urlFor(item: item)
        #if os(iOS)
        let options: Data.WritingOptions = .completeFileProtection
        #else
        let options: Data.WritingOptions = .atomic
        #endif
        try data.write(to: url, options: options)
        try persistMetadata(for: item)
    }

    public func fetchItem(_ id: UUID, in vault: UUID) async throws -> Data {
        let url = baseURL.appendingPathComponent(vault.uuidString).appendingPathComponent("\(id.uuidString).fv")
        return try Data(contentsOf: url)
    }

    public func listItems(in vault: UUID) async throws -> [VaultItem] {
        let metaURL = baseURL.appendingPathComponent(vault.uuidString).appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metaURL) else { return [] }
        return try JSONDecoder().decode([VaultItem].self, from: data)
    }

    public func deleteItem(_ id: UUID, in vault: UUID) async throws {
        let url = baseURL.appendingPathComponent(vault.uuidString).appendingPathComponent("\(id.uuidString).fv")
        try? fileManager.removeItem(at: url)
        let items = try await listItems(in: vault).filter { $0.id != id }
        let metaURL = baseURL.appendingPathComponent(vault.uuidString).appendingPathComponent("metadata.json")
        let data = try JSONEncoder().encode(items)
        #if os(iOS)
        let options: Data.WritingOptions = .completeFileProtection
        #else
        let options: Data.WritingOptions = .atomic
        #endif
        try data.write(to: metaURL, options: options)
    }

    public func synchronize() async throws {}

    private func urlFor(item: VaultItem) -> URL {
        let vaultFolder = baseURL.appendingPathComponent(item.vaultId.uuidString)
        try? fileManager.createDirectory(at: vaultFolder, withIntermediateDirectories: true)
        return vaultFolder.appendingPathComponent("\(item.id.uuidString).fv")
    }

    private func persistMetadata(for item: VaultItem) throws {
        let metaURL = baseURL.appendingPathComponent(item.vaultId.uuidString).appendingPathComponent("metadata.json")
        var items = (try? Data(contentsOf: metaURL)).flatMap { try? JSONDecoder().decode([VaultItem].self, from: $0) } ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        let data = try JSONEncoder().encode(items)
        #if os(iOS)
        let options: Data.WritingOptions = .completeFileProtection
        #else
        let options: Data.WritingOptions = .atomic
        #endif
        try data.write(to: metaURL, options: options)
    }
}

#if canImport(CloudKit)
public final class CloudKitStorageProvider: StorageProvider {
    private let database: CKDatabase

    public init(database: CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.database = database
    }

    public func saveItem(_ item: VaultItem, data: Data) async throws {
        let record = CKRecord(recordType: "VaultItem", recordID: CKRecord.ID(recordName: item.id.uuidString))
        record["vaultId"] = item.vaultId.uuidString as NSString
        record["metadata"] = try JSONEncoder().encode(item.metadata) as NSData
        record["payload"] = data as NSData
        try await database.save(record)
    }

    public func fetchItem(_ id: UUID, in vault: UUID) async throws -> Data {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = try await database.record(for: recordID)
        guard let data = record["payload"] as? Data else {
            throw AppError.storageFailure("Missing payload")
        }
        return data
    }

    public func listItems(in vault: UUID) async throws -> [VaultItem] {
        let predicate = NSPredicate(format: "vaultId == %@", vault.uuidString)
        let query = CKQuery(recordType: "VaultItem", predicate: predicate)
        var items: [VaultItem] = []
        let (results, _) = try await database.records(matching: query)
        for (recordID, result) in results {
            switch result {
            case .success(let record):
                guard let metadataData = record["metadata"] as? Data,
                      let metadata = try? JSONDecoder().decode(VaultItemMetadata.self, from: metadataData) else {
                    continue
                }
                let item = VaultItem(
                    id: UUID(uuidString: recordID.recordName) ?? UUID(),
                    vaultId: vault,
                    type: .document,
                    encryptedBlobReference: recordID.recordName,
                    metadata: metadata
                )
                items.append(item)
            case .failure:
                continue
            }
        }
        return items
    }

    public func deleteItem(_ id: UUID, in vault: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        _ = try await database.deleteRecord(withID: recordID)
    }

    public func synchronize() async throws {}
}
#endif
