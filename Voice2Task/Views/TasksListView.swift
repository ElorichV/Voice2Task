import SwiftData
import SwiftUI

struct TasksListView: View {
    private enum EditorPresentation: Identifiable {
        case create
        case edit(TaskItem)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let task): "edit-\(task.id.uuidString)"
            }
        }
    }

    @Environment(TasksViewModel.self) private var tasksViewModel
    @Environment(GitHubViewModel.self) private var gitHubViewModel
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var editorPresentation: EditorPresentation?
    @State private var showCelebration = false
    @State private var celebrationTimeout: Task<Void, Never>?

    private var pendingTasks: [TaskItem] { TasksViewModel.sorted(tasks.filter { !$0.isCompleted }) }
    private var completedTasks: [TaskItem] { TasksViewModel.sorted(tasks.filter(\.isCompleted)) }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("Sin tareas todavía — graba una nota o toca +")
                        } icon: {
                            MascotView(size: 88, mood: .happy)
                        }
                    } description: {
                        Text("Tus tareas aparecerán aquí.")
                    }
                } else {
                    List {
                        Section {
                            progressHeader
                        }
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
            .overlay {
                if showCelebration {
                    VStack(spacing: 12) {
                        MascotView(size: 112, mood: .happy)
                            .scaleEffect(showCelebration ? 1 : 0.85)
                        Text("¡Todo listo!")
                            .font(.title2.bold())
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Tareas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorPresentation = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Añadir tarea")
                }
            }
            .sheet(item: $editorPresentation) { presentation in
                switch presentation {
                case .create:
                    TaskEditorView()
                case .edit(let task):
                    TaskEditorView(task: task)
                }
            }
            .onChange(of: tasks.map(\.isCompleted)) { oldValue, newValue in
                guard oldValue.count == newValue.count,
                      oldValue.contains(false),
                      !newValue.contains(false) else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showCelebration = true
                }
                celebrationTimeout?.cancel()
                celebrationTimeout = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    withAnimation { showCelebration = false }
                }
            }
            .onDisappear { celebrationTimeout?.cancel() }
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
            onSelect: { editorPresentation = .edit(task) },
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

    private var progressHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: Double(completedTasks.count) / Double(tasks.count))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(completedTasks.count)/\(tasks.count)")
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            .frame(width: 52, height: 52)
            .accessibilityLabel("\(completedTasks.count) de \(tasks.count) completadas")

            VStack(alignment: .leading, spacing: 8) {
                Text("\(completedTasks.count) de \(tasks.count) completadas")
                    .font(.headline)
                HStack(spacing: 8) {
                    metricChip("Hoy: \(todayCount)")
                    metricChip("Vencidas: \(overdueCount)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var todayCount: Int {
        pendingTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }.count
    }

    private var overdueCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return pendingTasks.filter { ($0.dueDate ?? .distantFuture) < startOfToday }.count
    }

    private func metricChip(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
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
