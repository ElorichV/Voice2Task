import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let isSyncing: Bool
    let onToggle: () -> Void
    let onSync: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.green : task.priority.color)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "Marcar como pendiente" : "Marcar como completada")

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    PriorityBadge(priority: task.priority)

                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(isOverdue(dueDate) ? .red : .secondary)
                    }

                    if let number = task.githubIssueNumber, task.syncedToGitHub {
                        Label("#\(number)", systemImage: "checkmark.icloud")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer(minLength: 0)

            if isSyncing {
                ProgressView()
            } else if !task.syncedToGitHub {
                Button(action: onSync) {
                    Image(systemName: "arrow.up.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Subir a GitHub")
            }
        }
        .padding(.vertical, 4)
    }

    private func isOverdue(_ date: Date) -> Bool {
        !task.isCompleted && date < Calendar.current.startOfDay(for: .now)
    }
}
