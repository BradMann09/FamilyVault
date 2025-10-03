import Foundation
import CoreKit

public actor VitalChecklistService {
    private(set) var items: [VitalChecklistItem]
    private let reminderEngine: ReminderEngine

    public init(items: [VitalChecklistItem] = VitalChecklistSeeds.defaultItems, reminderEngine: ReminderEngine) {
        self.items = items
        self.reminderEngine = reminderEngine
    }

    public func itemsList() -> [VitalChecklistItem] {
        items
    }

    public func checklistProgress() -> Double {
        let total = Double(items.count)
        guard total > 0 else { return 0 }
        let completed = Double(items.filter { $0.status == .present }.count)
        return completed / total
    }

    public func item(with id: UUID) -> VitalChecklistItem? {
        items.first(where: { $0.id == id })
    }

    public func update(itemId: UUID, status: VitalStatus, dueDate: Date?, vaultItemId: UUID?) async {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].status = status
        items[index].dueDate = dueDate
        items[index].vaultItemId = vaultItemId
        await reminderEngine.scheduleReminderIfNeeded(for: items[index])
    }

    public func missingItems() -> [VitalChecklistItem] {
        items.filter { $0.status == .missing }
    }

    public func expiringSoonItems(referenceDate: Date = .now) -> [VitalChecklistItem] {
        items.filter { item in
            guard let due = item.dueDate else { return false }
            return item.status == .expiringSoon && due > referenceDate
        }
    }
}

public enum VitalChecklistSeeds {
    public static var defaultItems: [VitalChecklistItem] {
        [
            VitalChecklistItem(title: "Primary Passport", category: .identity),
            VitalChecklistItem(title: "Secondary Passport", category: .identity),
            VitalChecklistItem(title: "Family Will", category: .legal),
            VitalChecklistItem(title: "Power of Attorney", category: .legal),
            VitalChecklistItem(title: "Medical Directive", category: .medical),
            VitalChecklistItem(title: "Home Insurance Policy", category: .insurance),
            VitalChecklistItem(title: "Life Insurance Policy", category: .insurance),
            VitalChecklistItem(title: "Emergency Contacts", category: .emergency)
        ]
    }
}

public protocol VitalClassifier: Sendable {
    func classify(documentText: String) -> VitalCategory
    func detectExpiry(in text: String, reference: Date) -> Date?
}

public struct HeuristicVitalClassifier: VitalClassifier {
    private let calendar = Calendar(identifier: .gregorian)

    public init() {}

    public func classify(documentText: String) -> VitalCategory {
        let lower = documentText.lowercased()
        if lower.contains("passport") { return .identity }
        if lower.contains("insurance") { return .insurance }
        if lower.contains("will") || lower.contains("estate") { return .legal }
        if lower.contains("medical") || lower.contains("health") { return .medical }
        if lower.contains("contact") { return .emergency }
        return .other
    }

    public func detectExpiry(in text: String, reference: Date = .now) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)) ?? []
        let upcoming = matches.compactMap { $0.date }.filter { $0 > reference }
        return upcoming.sorted().first
    }
}

public actor ReminderEngine {
    public struct Reminder: Identifiable, Sendable {
        public let id: UUID
        public let checklistId: UUID
        public let dueDate: Date
        public let message: String
    }

    private var scheduled: [Reminder] = []

    public init() {}

    public func scheduleReminderIfNeeded(for item: VitalChecklistItem) async {
        guard let due = item.dueDate else { return }
        if item.status == .missing {
            let reminder = Reminder(id: UUID(), checklistId: item.id, dueDate: due, message: "Document reminder")
            scheduled.append(reminder)
        } else if item.status == .expiringSoon {
            let reminder = Reminder(id: UUID(), checklistId: item.id, dueDate: due, message: "Document expiring soon")
            scheduled.append(reminder)
        }
    }

    public func reminders() -> [Reminder] { scheduled }
}
