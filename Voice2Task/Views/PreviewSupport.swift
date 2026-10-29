#if DEBUG
import SwiftData
import SwiftUI

@MainActor
enum PreviewSupport {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: TaskItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            for task in TaskItem.mockTasks {
                container.mainContext.insert(task)
            }
            return container
        } catch {
            fatalError("No se pudo crear el contenedor de previews: \(error)")
        }
    }()
}

extension View {
    @MainActor
    func withPreviewEnvironment() -> some View {
        let context = PreviewSupport.container.mainContext
        return modelContainer(PreviewSupport.container)
            .environment(RecordingViewModel(modelContext: context))
            .environment(TasksViewModel(modelContext: context))
            .environment(GitHubViewModel())
    }
}
#endif
