import SwiftData
import SwiftUI

@main
struct Voice2TaskApp: App {
    let modelContainer: ModelContainer

    @State private var recordingViewModel: RecordingViewModel
    @State private var tasksViewModel: TasksViewModel
    @State private var gitHubViewModel: GitHubViewModel

    init() {
        let container = AppModelContainer.shared
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
}
