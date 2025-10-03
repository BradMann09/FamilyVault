import SwiftUI

public struct AppSettings: Equatable {
    public var biometricUnlock: Bool
    public var panicLock: Bool
    public var remoteAssistantEnabled: Bool

    public init(biometricUnlock: Bool = true, panicLock: Bool = true, remoteAssistantEnabled: Bool = false) {
        self.biometricUnlock = biometricUnlock
        self.panicLock = panicLock
        self.remoteAssistantEnabled = remoteAssistantEnabled
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var settings: AppSettings

    public init(settings: AppSettings = .init()) {
        self.settings = settings
    }
}

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    private let onDismiss: () -> Void

    public init(viewModel: @escaping () -> SettingsViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Toggle("Unlock with Face ID", isOn: $viewModel.settings.biometricUnlock)
                    Toggle("Enable Panic Lock", isOn: $viewModel.settings.panicLock)
                }
                Section("Assistant") {
                    Toggle("Allow Remote Provider", isOn: $viewModel.settings.remoteAssistantEnabled)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
