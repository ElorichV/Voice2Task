import Foundation
import SwiftData

enum Priority: String, Codable, CaseIterable, Identifiable {
    case alta
    case media
    case baja

    var id: String { rawValue }

    /// Lower sorts first (alta → media → baja).
    var sortOrder: Int {
        switch self {
        case .alta: 0
        case .media: 1
        case .baja: 2
        }
    }

    var displayName: String {
        switch self {
        case .alta: "Alta"
        case .media: "Media"
        case .baja: "Baja"
        }
    }

    /// Lenient parsing for values coming from the AI (e.g. "Alta", "high", " media ").
    init(fromAI raw: String?) {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "alta", "high", "urgente": self = .alta
        case "baja", "low": self = .baja
        default: self = .media
        }
    }
}

/// Named `TaskItem` (not `Task`) so it doesn't shadow Swift Concurrency's `Task` across the module.
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var priority: Priority
    var dueDate: Date?
    var isCompleted: Bool
    var syncedToGitHub: Bool
    var githubIssueNumber: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        priority: Priority = .media,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        syncedToGitHub: Bool = false,
        githubIssueNumber: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.syncedToGitHub = syncedToGitHub
        self.githubIssueNumber = githubIssueNumber
        self.createdAt = createdAt
    }
}

extension TaskItem {
    static var mockTasks: [TaskItem] {
        [
            TaskItem(title: "Preparar demo del pitch", priority: .alta, dueDate: .now),
            TaskItem(title: "Revisar integración con GitHub", priority: .media),
            TaskItem(title: "Diseñar ícono de la app", priority: .baja),
        ]
    }
}
