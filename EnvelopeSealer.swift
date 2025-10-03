import Foundation
import CryptoKit

public struct EnvelopeSealer: Sendable {
    public struct Envelope: Codable, Sendable {
        public let ciphertext: Data
        public let nonce: Data
        public let tag: Data
        public let metadata: [String: String]

        public init(ciphertext: Data, nonce: Data, tag: Data, metadata: [String: String]) {
            self.ciphertext = ciphertext
            self.nonce = nonce
            self.tag = tag
            self.metadata = metadata
        }
    }

    public init() {}

    public func seal(data: Data, metadata: [String: String], using key: SymmetricKey) throws -> Envelope {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return Envelope(
            ciphertext: sealedBox.ciphertext,
            nonce: sealedBox.nonce.data,
            tag: sealedBox.tag,
            metadata: metadata
        )
    }

    public func open(envelope: Envelope, using key: SymmetricKey) throws -> Data {
        let nonce = try AES.GCM.Nonce(data: envelope.nonce)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: envelope.ciphertext, tag: envelope.tag)
        return try AES.GCM.open(sealed, using: key)
    }
}

private extension AES.GCM.Nonce {
    var data: Data {
        Data(self)
    }
}
