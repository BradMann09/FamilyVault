import SwiftUI
import CoreKit

public struct MembersView: View {
    private let members: [Member]
    private let onInvite: () -> Void

    public init(members: [Member], onInvite: @escaping () -> Void) {
        self.members = members
        self.onInvite = onInvite
    }

    public var body: some View {
        List {
            Section("Members") {
                ForEach(members) { member in
                    VStack(alignment: .leading) {
                        Text(member.profile.name)
                            .font(.headline)
                        Text(member.role.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toolbar {
            Button(action: onInvite) {
                Image(systemName: "person.badge.plus")
            }
        }
        .navigationTitle("Members")
    }
}
