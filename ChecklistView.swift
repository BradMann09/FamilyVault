import SwiftUI
import VitalKit

public struct ChecklistView: View {
    private let items: [VitalChecklistItem]
    private let onRefresh: @Sendable () async -> Void

    public init(items: [VitalChecklistItem], onRefresh: @escaping @Sendable () async -> Void) {
        self.items = items
        self.onRefresh = onRefresh
    }

    public var body: some View {
        List {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.status.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(statusColor(for: item.status))
                    if let due = item.dueDate {
                        Text(due, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { await onRefresh() }
        .navigationTitle("Vital Checklist")
    }

    private func statusColor(for status: VitalStatus) -> Color {
        switch status {
        case .missing: return .red
        case .present: return .green
        case .expiringSoon: return .orange
        case .expired: return .red
        }
    }
}
