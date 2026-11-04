import Foundation

enum ExtractionEngine: String {
    case openAI
    case appleIntelligence
    case local

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .appleIntelligence: "Apple Intelligence (en el dispositivo)"
        case .local: "IA local sin conexión"
        }
    }

    var systemImage: String {
        switch self {
        case .openAI: "cloud"
        case .appleIntelligence: "apple.intelligence"
        case .local: "cpu"
        }
    }
}

@MainActor
struct TaskExtractionService {
    var openAIKey = Constants.openAIAPIKey
    var useMockData = Constants.useMockData

    func extractTasks(from text: String) async throws -> (tasks: [TaskItem], engine: ExtractionEngine) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw OpenAIServiceError.emptyText }

        if useMockData {
            try? await Task.sleep(for: .milliseconds(800))
            return try result(from: LocalTaskExtractor().extract(from: trimmedText), engine: .local)
        }

        if !openAIKey.isEmpty {
            do {
                let tasks = try await OpenAIService(apiKey: openAIKey, useMockData: false)
                    .extractTasks(from: trimmedText)
                return (tasks, .openAI)
            } catch {
                if let drafts = try? await extractWithAppleIntelligence(from: trimmedText),
                   !drafts.isEmpty {
                    return try result(from: drafts, engine: .appleIntelligence)
                }
                throw error
            }
        }

        if let drafts = try? await extractWithAppleIntelligence(from: trimmedText), !drafts.isEmpty {
            return try result(from: drafts, engine: .appleIntelligence)
        }
        return try result(from: LocalTaskExtractor().extract(from: trimmedText), engine: .local)
    }

    private func extractWithAppleIntelligence(from text: String) async throws -> [TaskDraft]? {
        guard #available(iOS 26.0, *), OnDeviceAIExtractor.isAvailable else { return nil }
        return try await OnDeviceAIExtractor().extract(from: text)
    }

    private func result(from drafts: [TaskDraft], engine: ExtractionEngine) throws -> (tasks: [TaskItem], engine: ExtractionEngine) {
        let tasks = drafts.map {
            TaskItem(title: $0.title, priority: $0.priority, dueDate: $0.dueDate)
        }
        guard !tasks.isEmpty else { throw OpenAIServiceError.noTasksFound }
        return (tasks, engine)
    }
}
