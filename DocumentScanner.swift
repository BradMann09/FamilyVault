import Foundation
import CoreKit
import VitalKit

public struct ScanResult: Sendable {
    public let imageData: Data
    public let extractedText: String
}

public protocol DocumentScanner: Sendable {
    func scan() async throws -> ScanResult
}

public protocol OCRProcessor: Sendable {
    func extractText(from data: Data) async throws -> String
}

public final class StubDocumentScanner: DocumentScanner {
    public init() {}

    public func scan() async throws -> ScanResult {
        let data = Data()
        return ScanResult(imageData: data, extractedText: "Sample passport 2030-05-01")
    }
}

public final class SimpleOCRProcessor: OCRProcessor {
    public init() {}

    public func extractText(from data: Data) async throws -> String {
        guard !data.isEmpty else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public actor OCRPipeline {
    private let scanner: DocumentScanner
    private let ocr: OCRProcessor
    private let classifier: VitalClassifier

    public init(scanner: DocumentScanner, ocr: OCRProcessor, classifier: VitalClassifier) {
        self.scanner = scanner
        self.ocr = ocr
        self.classifier = classifier
    }

    public func captureAndClassify(referenceDate: Date = .now) async throws -> (text: String, category: VitalCategory, expiry: Date?) {
        let scan = try await scanner.scan()
        let text = try await ocr.extractText(from: scan.imageData)
        let category = classifier.classify(documentText: text)
        let expiry = classifier.detectExpiry(in: text, reference: referenceDate)
        return (text, category, expiry)
    }
}
