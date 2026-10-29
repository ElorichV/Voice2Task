import SwiftData
import SwiftUI

struct TasksListView: View {
    @Environment(TasksViewModel.self) private var tasksViewModel
    @Environment(GitHubViewModel.self) private var gitHubViewModel
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    private var pendingTasks: [TaskItem] { TasksViewModel.sorted(tasks.filter { !$0.isCompleted }) }
    private var completedTasks: [TaskItem] { TasksViewModel.sorted(tasks.filter(\.isCompleted)) }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "Sin tareas",
                        systemImage: "checklist",
                        description: Text("Graba una nota de voz o pega un texto en la pestaña Grabar.")
                    )
                } else {
                    List {
                        if !pendingTasks.isEmpty {
                            Section("Pendientes (\(pendingTasks.count))") {
                                ForEach(pendingTasks) { row(for: $0) }
                            }
                        }
                        if !completedTasks.isEmpty {
                            Section("Completadas (\(completedTasks.count))") {
                                ForEach(completedTasks) { row(for: $0) }
                            }
                        }
                    }
                    .animation(.default, value: tasks.map(\.isCompleted))
                }
            }
            .navigationTitle("Tareas")
            .alert("Error", isPresented: tasksErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(tasksViewModel.errorMessage ?? "")
            }
        }
        .alert(syncAlertTitle, isPresented: syncAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(gitHubViewModel.syncErrorMessage ?? gitHubViewModel.syncSuccessMessage ?? "")
        }
    }

    private func row(for task: TaskItem) -> some View {
        TaskRowView(
            task: task,
            isSyncing: gitHubViewModel.isSyncing(task),
            onToggle: { withAnimation { tasksViewModel.toggleCompletion(task) } },
            onSync: { sync(task) }
        )
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { tasksViewModel.toggleCompletion(task) }
            } label: {
                Label(task.isCompleted ? "Pendiente" : "Completar", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { tasksViewModel.delete(task) }
            } label: {
                Label("Eliminar", systemImage: "trash")
            }

            if !task.syncedToGitHub {
                Button {
                    sync(task)
                } label: {
                    Label("Subir a GitHub", systemImage: "arrow.up.circle")
                }
                .tint(.blue)
            }
        }
    }

    private func sync(_ task: TaskItem) {
        Task { await gitHubViewModel.sync(task, tasksViewModel: tasksViewModel) }
    }

    private var syncAlertTitle: String {
        gitHubViewModel.syncErrorMessage != nil ? "No se pudo subir a GitHub" : "Listo"
    }

    private var syncAlertBinding: Binding<Bool> {
        Binding(
            get: { gitHubViewModel.syncErrorMessage != nil || gitHubViewModel.syncSuccessMessage != nil },
            set: { isPresented in
                if !isPresented {
                    gitHubViewModel.syncErrorMessage = nil
                    gitHubViewModel.syncSuccessMessage = nil
                }
            }
        )
    }

    private var tasksErrorBinding: Binding<Bool> {
        Binding(
            get: { tasksViewModel.errorMessage != nil },
            set: { if !$0 { tasksViewModel.errorMessage = nil } }
        )
    }
}

#if DEBUG
#Preview {
    TasksListView()
        .withPreviewEnvironment()
}
#endif
