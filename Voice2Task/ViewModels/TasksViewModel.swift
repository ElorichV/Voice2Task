import Foundation
import Observation
import SwiftData

/// Actions on tasks. `@Query` only works inside SwiftUI views, so `TasksListView` owns the live
/// `@Query` and calls into this view model for mutations.
@MainActor
@Observable
final class TasksViewModel {
    var errorMessage: String?

    @ObservationIgnored private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func toggleCompletion(_ task: TaskItem) {
        task.isCompleted.toggle()
        save()
    }

    func delete(_ task: TaskItem) {
        modelContext.delete(task)
        save()
    }

    /// Throws if the link can't be persisted. The in-memory task stays marked so it isn't uploaded twice this session.
    func markAsSynced(_ task: TaskItem, issueNumber: Int) throws {
        task.syncedToGitHub = true
        task.githubIssueNumber = issueNumber
        try modelContext.save()
    }

    func fetchTasks() -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            return Self.sorted(try modelContext.fetch(descriptor))
        } catch {
            errorMessage = "No se pudieron cargar las tareas: \(error.localizedDescription)"
            return []
        }
    }

    /// Pending first, then by priority (alta → baja), then by due date (soonest first, no date last).
    static func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.priority != rhs.priority { return lhs.priority.sortOrder < rhs.priority.sortOrder }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?) where l != r: return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            default: return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "No se pudieron guardar los cambios: \(error.localizedDescription)"
        }
    }
}
