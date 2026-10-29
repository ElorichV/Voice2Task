import SwiftData
import SwiftUI

@main
struct Voice2TaskApp: App {
    let modelContainer: ModelContainer

    @State private var recordingViewModel: RecordingViewModel
    @State private var tasksViewModel: TasksViewModel
    @State private var gitHubViewModel: GitHubViewModel

    init() {
        let container = Self.makeModelContainer()
        modelContainer = container
        _recordingViewModel = State(initialValue: RecordingViewModel(modelContext: container.mainContext))
        _tasksViewModel = State(initialValue: TasksViewModel(modelContext: container.mainContext))
        _gitHubViewModel = State(initialValue: GitHubViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(recordingViewModel)
                .environment(tasksViewModel)
                .environment(gitHubViewModel)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: TaskItem.self)
        } catch {
            // Fallback: if the on-disk store can't be opened, keep the app usable with an in-memory store.
            do {
                return try ModelContainer(for: TaskItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("No se pudo crear el ModelContainer: \(error)")
            }
        }
    }
}
