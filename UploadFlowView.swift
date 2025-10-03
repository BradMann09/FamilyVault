import SwiftUI
import CoreKit
import VaultKit
import VitalKit
import ScannerKit

@MainActor
public final class UploadFlowViewModel: ObservableObject {
    @Published public var titleHint: String = ""
    @Published public var category: VitalCategory = .other
    @Published public var expiryDate: Date?
    @Published public var isScanning = false
    @Published public var statusMessage: String = ""

    private let vault: Vault
    private let member: Member
    private let vaultService: VaultService
    private let pipeline: OCRPipeline
    private let checklist: VitalChecklistService

    public init(vault: Vault, member: Member, vaultService: VaultService, pipeline: OCRPipeline, checklist: VitalChecklistService) {
        self.vault = vault
        self.member = member
        self.vaultService = vaultService
        self.pipeline = pipeline
        self.checklist = checklist
    }

    public func scanDocument() async {
        isScanning = true
        defer { isScanning = false }
        do {
            let result = try await pipeline.captureAndClassify()
            titleHint = result.text.components(separatedBy: "\n").first ?? "Scanned Document"
            category = result.category
            expiryDate = result.expiry
            statusMessage = "Document classified as \(category.rawValue)."
        } catch {
            statusMessage = "Scan failed."
        }
    }

    public func upload(data: Data) async {
        do {
            let metadata = VaultItemMetadata(
                titleHint: titleHint.isEmpty ? "Untitled" : titleHint,
                redactedAttributes: ["category": category.rawValue],
                expiresAt: expiryDate,
                checklistCategory: category
            )
            let item = try await vaultService.upload(item: data, metadata: metadata, to: vault.id, by: member)
            let items = await checklist.itemsList()
            if let checklistItem = items.first(where: { $0.title.lowercased().contains(category.rawValue) }) {
                await checklist.update(itemId: checklistItem.id, status: .present, dueDate: expiryDate, vaultItemId: item.id)
            }
            statusMessage = "Upload complete."
        } catch {
            statusMessage = "Upload failed."
        }
    }
}

public struct UploadFlowView: View {
    @StateObject private var viewModel: UploadFlowViewModel
    private let onFinish: () -> Void

    public init(viewModel: @escaping () -> UploadFlowViewModel, onFinish: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onFinish = onFinish
    }

    public var body: some View {
        Form {
            Section("Document Details") {
                TextField("Title", text: $viewModel.titleHint)
                Picker("Category", selection: $viewModel.category) {
                    ForEach(VitalCategory.allCases, id: \.self) { category in
                        Text(category.rawValue.capitalized).tag(category)
                    }
                }
                DatePicker("Expiry", selection: Binding(get: {
                    viewModel.expiryDate ?? Date()
                }, set: { newValue in
                    viewModel.expiryDate = newValue
                }), displayedComponents: .date)
                .opacity(viewModel.expiryDate == nil ? 0.4 : 1)
            }

            Section("Actions") {
                if viewModel.isScanning {
                    ProgressView()
                } else {
                    Button("Scan Document") {
                        Task { await viewModel.scanDocument() }
                    }
                }

                Button("Upload") {
                    Task { await viewModel.upload(data: Data(viewModel.titleHint.utf8)) }
                    onFinish()
                }
                .disabled(viewModel.titleHint.isEmpty)
            }

            if !viewModel.statusMessage.isEmpty {
                Section {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Upload")
    }
}
