import SwiftUI
import SwiftData

@main
struct Voice2TaskApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: TaskItem.self)
        } catch {
            // Fallback: if the on-disk store can't be opened, keep the app usable with an in-memory store.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: TaskItem.self, configurations: config)
            } catch {
                fatalError("No se pudo crear el ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
