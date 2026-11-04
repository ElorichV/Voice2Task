import AppIntents
import SwiftData

struct CreateTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Crear tareas"
    static let description = IntentDescription("Convierte un texto en tareas con prioridad y fecha.")

    @Parameter(title: "Texto", requestValueDialog: "¿Qué tienes que hacer?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await TaskExtractionService().extractTasks(from: text)
        let context = AppModelContainer.shared.mainContext
        for task in result.tasks {
            context.insert(task)
        }
        try context.save()

        let titles = result.tasks.prefix(3).map(\.title).joined(separator: ", ")
        let dialog = result.tasks.count == 1
            ? "Listo, agregué 1 tarea: \(titles)."
            : "Listo, agregué \(result.tasks.count) tareas: \(titles)."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct Voice2TaskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTasksIntent(),
            phrases: [
                "Crear tareas con \(.applicationName)",
                "Agregar tareas en \(.applicationName)",
                "Nueva nota en \(.applicationName)",
            ],
            shortTitle: "Crear tareas",
            systemImageName: "checklist"
        )
    }
}
