#if canImport(FoundationModels)
import Foundation
import FoundationModels

@MainActor
@available(iOS 26.0, *)
struct OnDeviceAIExtractor {
    static var isAvailable: Bool {
        return SystemLanguageModel.default.isAvailable
    }

    func extract(from text: String, now: Date = .now) async throws -> [TaskDraft] {
        let session = LanguageModelSession(instructions: """
        Extrae tareas accionables del texto en español. Para cada tarea, incluye un título breve, \
        una prioridad alta, media o baja y una fecha límite en formato YYYY-MM-DD relativa a la \
        fecha de hoy que te doy. Usa null si no hay una fecha explícita. No inventes tareas ni fechas.
        """)
        let today = OpenAIService.dateFormatter.string(from: now)
        let response = try await session.respond(
            to: "Fecha de hoy: \(today).\n\nTexto:\n\(text)",
            generating: GeneratedTaskCollection.self
        )

        return response.content.tasks.compactMap { generated in
            let title = generated.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return TaskDraft(
                title: title,
                priority: Priority(fromAI: generated.priority),
                dueDate: generated.dueDate.flatMap { OpenAIService.dateFormatter.date(from: $0) }
            )
        }
    }
}

@Generable
@available(iOS 26.0, *)
private struct GeneratedTaskCollection {
    @Guide(description: "Lista de tareas accionables extraídas del texto.")
    var tasks: [GeneratedTask]
}

@Generable
@available(iOS 26.0, *)
private struct GeneratedTask {
    @Guide(description: "Título breve y accionable de la tarea.")
    var title: String

    @Guide(description: "Prioridad de la tarea: alta, media o baja.")
    var priority: String

    @Guide(description: "Fecha límite como YYYY-MM-DD, o null si no hay fecha explícita.")
    var dueDate: String?
}
#endif
