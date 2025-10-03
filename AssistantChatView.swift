import SwiftUI
import AssistantKit
import CoreKit
import VitalKit

public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let isUser: Bool

    public init(id: UUID = UUID(), text: String, isUser: Bool) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }
}

@MainActor
public final class AssistantChatViewModel: ObservableObject {
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public var input: String = ""
    @Published public private(set) var actions: [AssistantAction] = []
    @Published public private(set) var followUps: [String] = []

    private let engine: AssistantEngine
    private let contextProvider: () async -> AssistantContext

    public init(engine: AssistantEngine, contextProvider: @escaping () async -> AssistantContext) {
        self.engine = engine
        self.contextProvider = contextProvider
    }

    public func sendMessage() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(text: text, isUser: true))
        input = ""

        let context = await contextProvider()
        if let response = try? await engine.handle(text, context: context) {
            messages.append(ChatMessage(text: response.message, isUser: false))
            actions = response.actions
            followUps = response.followUps
        } else {
            messages.append(ChatMessage(text: "Assistant unavailable.", isUser: false))
            actions = []
            followUps = []
        }
    }
}

public struct AssistantChatView: View {
    @StateObject private var viewModel: AssistantChatViewModel
    private let onAction: (AssistantAction) -> Void

    public init(viewModel: @escaping () -> AssistantChatViewModel, onAction: @escaping (AssistantAction) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.isUser { Spacer() }
                            Text(message.text)
                                .padding(12)
                                .background(message.isUser ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundStyle(message.isUser ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            if !message.isUser { Spacer() }
                        }
                    }
                }
                .padding()
            }
            if !viewModel.actions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { _, action in
                            Button(actionLabel(for: action)) {
                                onAction(action)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            if !viewModel.followUps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.followUps, id: \.self) { followUp in
                            Button(followUp) {
                                viewModel.input = followUp
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
            }
            HStack {
                TextField("Ask FamilyVault", text: $viewModel.input)
                    .textFieldStyle(.roundedBorder)
                Button(action: { Task { await viewModel.sendMessage() } }) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(viewModel.input.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Assistant")
    }
}

fileprivate func actionLabel(for action: AssistantAction) -> String {
    switch action {
    case .openChecklist: return "Checklist"
    case .openVaultItem: return "Open Item"
    case .openLegacyAccess: return "Legacy"
    case .scheduleReminder: return "Remind"
    case .openUpload: return "Upload"
    }
}
