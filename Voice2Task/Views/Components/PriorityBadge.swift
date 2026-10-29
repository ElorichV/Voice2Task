import SwiftUI

extension Priority {
    var color: Color {
        switch self {
        case .alta: .red
        case .media: .yellow
        case .baja: .green
        }
    }
}

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priority.color.opacity(0.2), in: Capsule())
            .overlay(Capsule().strokeBorder(priority.color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(.primary)
    }
}

#Preview {
    HStack {
        ForEach(Priority.allCases) { PriorityBadge(priority: $0) }
    }
}
