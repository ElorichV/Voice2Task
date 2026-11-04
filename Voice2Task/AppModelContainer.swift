import SwiftData

@MainActor
enum AppModelContainer {
    static let shared: ModelContainer = make()

    private static func make() -> ModelContainer {
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
