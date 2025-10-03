import Foundation

public enum AppError: Error, LocalizedError, Sendable {
    case vaultNotFound
    case itemNotFound
    case userNotAuthorized
    case encryptionFailed
    case decryptionFailed
    case storageFailure(String)
    case networkUnavailable
    case secureEnclaveUnavailable
    case keyDerivationFailed
    case invalidPolicy
    case assistantUnavailable
    case ocrFailure

    public var errorDescription: String? {
        switch self {
        case .vaultNotFound:
            return "Vault could not be located."
        case .itemNotFound:
            return "Requested vault item does not exist."
        case .userNotAuthorized:
            return "You are not authorized for this action."
        case .encryptionFailed:
            return "Unable to encrypt data."
        case .decryptionFailed:
            return "Unable to decrypt data."
        case .storageFailure(let message):
            return "Storage error: \(message)."
        case .networkUnavailable:
            return "Network is currently unavailable."
        case .secureEnclaveUnavailable:
            return "Secure Enclave is not available on this device."
        case .keyDerivationFailed:
            return "Could not derive necessary encryption keys."
        case .invalidPolicy:
            return "Access policy invalid or incomplete."
        case .assistantUnavailable:
            return "Assistant currently unavailable."
        case .ocrFailure:
            return "Failed to classify the document."
        }
    }
}

public struct RecoverableError: Error, Sendable {
    public let underlying: Error
    public let retryAfter: TimeInterval?

    public init(underlying: Error, retryAfter: TimeInterval? = nil) {
        self.underlying = underlying
        self.retryAfter = retryAfter
    }
}
