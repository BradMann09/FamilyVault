import SwiftUI

public struct OnboardingView: View {
    private let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        TabView {
            onboardingPage(
                title: "Secure Your Family",
                subtitle: "Protect passports, wills, and insurance documents with end-to-end encryption."
            )
            onboardingPage(
                title: "Stay Prepared",
                subtitle: "Vital checklist and smart reminders keep everything up to date."
            )
            onboardingPage(
                title: "Guided Assistance",
                subtitle: "Assistant helps you navigate and manage legacy access."
            )
        }
        .tabViewStyle(.page)
        .overlay(alignment: .bottom) {
            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func onboardingPage(title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
