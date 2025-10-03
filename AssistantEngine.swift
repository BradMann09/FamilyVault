import Foundation
import CoreKit
import VitalKit
import VaultKit

public struct AssistantContext: Sendable {
    public let user: UserProfile
    public let vaults: [Vault]
    public let checklist: [VitalChecklistItem]
}

public struct AssistantResponse: Sendable {
    public let message: String
    public let actions: [AssistantAction]
    public let followUps: [String]
}

public enum AssistantAction: Sendable, Hashable {
    case openChecklist
    case openVaultItem(UUID)
    case openLegacyAccess
    case scheduleReminder(UUID)
    case openUpload
}

public protocol AssistantTool: Sendable {
    var name: String { get }
    func canHandle(utterance: String) -> Bool
    func handle(utterance: String, context: AssistantContext) async throws -> AssistantResponse
}

public protocol AssistantProvider: Sendable {
    func respond(to message: String, context: AssistantContext) async throws -> AssistantResponse
}

public actor AssistantEngine {
    private let provider: AssistantProvider
    private let tools: [AssistantTool]

    public init(provider: AssistantProvider, tools: [AssistantTool]) {
        self.provider = provider
        self.tools = tools
    }

    public func handle(_ message: String, context: AssistantContext) async throws -> AssistantResponse {
        if let tool = tools.first(where: { $0.canHandle(utterance: message) }) {
            return try await tool.handle(utterance: message, context: context)
        }
        return try await provider.respond(to: message, context: context)
    }
}

public struct ProactiveAssistantScheduler: Sendable {
    public init() {}

    public func reminders(for checklist: [VitalChecklistItem], reference: Date = .now) -> [AssistantResponse] {
        checklist.compactMap { item in
            guard let due = item.dueDate else { return nil }
            let remaining = due.timeIntervalSince(reference)
            if remaining < 7 * 24 * 60 * 60, item.status != .present {
                let message = "Your \(item.title) expires soon. Would you like to scan it now?"
                return AssistantResponse(
                    message: message,
                    actions: [.openUpload, .scheduleReminder(item.id)],
                    followUps: ["Scan now", "Remind me later"]
                )
            }
            return nil
        }
    }
}

public struct ChecklistTool: AssistantTool {
    public let name = "checklist"
    private let reminderEngine: ReminderEngine

    public init(reminderEngine: ReminderEngine) {
        self.reminderEngine = reminderEngine
    }

    public func canHandle(utterance: String) -> Bool {
        utterance.lowercased().contains("missing") || utterance.lowercased().contains("checklist")
    }

    public func handle(utterance: String, context: AssistantContext) async throws -> AssistantResponse {
        let missing = context.checklist.filter { $0.status == .missing }
        let message: String
        if missing.isEmpty {
            message = "All vital documents are present."
        } else {
            let titles = missing.map { $0.title }.joined(separator: ", ")
            message = "You are missing: \(titles)."
        }
        return AssistantResponse(
            message: message,
            actions: [.openChecklist],
            followUps: ["Add document", "Set reminder"]
        )
    }
}

public struct VaultNavigationTool: AssistantTool {
    public let name = "navigation"

    public init() {}

    public func canHandle(utterance: String) -> Bool {
        utterance.lowercased().contains("where")
    }

    public func handle(utterance: String, context: AssistantContext) async throws -> AssistantResponse {
        let lower = utterance.lowercased()
        for vault in context.vaults {
            for item in try await items(in: vault) {
                if lower.contains(item.metadata.titleHint.lowercased()) {
                    return AssistantResponse(
                        message: "Opening \(item.metadata.titleHint)",
                        actions: [.openVaultItem(item.id)],
                        followUps: ["Share", "View details"]
                    )
                }
            }
        }
        return AssistantResponse(
            message: "I couldn't find that document yet.",
            actions: [.openChecklist],
            followUps: ["Upload document", "Search vault"]
        )
    }

    private func items(in vault: Vault) async throws -> [VaultItem] {
        // Placeholder: real implementation uses search index
        return []
    }
}

public struct LegacyTool: AssistantTool {
    public let name = "legacy"

    public init() {}

    public func canHandle(utterance: String) -> Bool {
        utterance.lowercased().contains("legacy")
    }

    public func handle(utterance: String, context: AssistantContext) async throws -> AssistantResponse {
        let explanation = "Legacy access lets trusted contacts unlock vaults after confirmations and time-lock."
        return AssistantResponse(
            message: explanation,
            actions: [.openLegacyAccess],
            followUps: ["Set legacy contact", "View policy"]
        )
    }
}

public struct OnDeviceAssistantProvider: AssistantProvider {
    public init() {}

    public func respond(to message: String, context: AssistantContext) async throws -> AssistantResponse {
        let trimmed = message.lowercased()
        if trimmed.contains("remind") {
            return AssistantResponse(
                message: "I'll remind you soon.",
                actions: [.openChecklist],
                followUps: ["View reminders", "Add reminder"]
            )
        }
        return AssistantResponse(
            message: "I'm here to help with your family vault.",
            actions: [.openChecklist],
            followUps: ["What's missing?", "Show expiring"]
        )
    }
}
