import Foundation

enum OpenAIServiceError: LocalizedError {
    case missingAPIKey
    case emptyText
    case network(URLError)
    case http(status: Int, message: String?)
    case invalidResponse
    case noTasksFound

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Falta la API key de OpenAI. Agrégala en la configuración o activa el modo de datos de prueba."
        case .emptyText:
            "No hay texto para procesar."
        case .network(let error):
            error.friendlyMessage
        case .http(let status, let message):
            switch status {
            case 401: "La API key de OpenAI no es válida."
            case 429: "Se alcanzó el límite de uso de OpenAI. Espera un momento e inténtalo de nuevo."
            case 500...599: "OpenAI no está disponible ahora mismo. Inténtalo más tarde."
            default: "Error de OpenAI (\(status))" + (message.map { ": \($0)" } ?? "")
            }
        case .invalidResponse:
            "La respuesta de la IA no tiene el formato esperado."
        case .noTasksFound:
            "La IA no encontró tareas accionables en el texto."
        }
    }
}

struct OpenAIService {
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let model = "gpt-4o-mini"
    static let systemPrompt = """
    Extrae tareas accionables del siguiente texto. Responde SOLO con un JSON válido con el formato: \
    { "tasks": [ { "title": "...", "priority": "alta|media|baja", "dueDate": "YYYY-MM-DD" o null } ] }
    """

    var apiKey: String = Constants.openAIAPIKey
    var useMockData: Bool = Constants.useMockData
    var session: URLSession = .shared

    func extractTasks(from text: String) async throws -> [TaskItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenAIServiceError.emptyText }

        if useMockData {
            try? await Task.sleep(for: .milliseconds(800))
            return TaskItem.mockTasks
        }

        guard !apiKey.isEmpty else { throw OpenAIServiceError.missingAPIKey }

        let request = try makeRequest(for: trimmed)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw OpenAIServiceError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw OpenAIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw OpenAIServiceError.http(status: http.statusCode, message: apiError?.error.message)
        }

        let tasks = try Self.parseTasks(from: data)
        guard !tasks.isEmpty else { throw OpenAIServiceError.noTasksFound }
        return tasks
    }

    // MARK: - Request

    private func makeRequest(for text: String) throws -> URLRequest {
        let today = Self.dateFormatter.string(from: .now)
        let body = ChatRequest(
            model: Self.model,
            messages: [
                .init(role: "system", content: Self.systemPrompt),
                .init(role: "user", content: "Fecha de hoy: \(today).\n\nTexto:\n\(text)"),
            ],
            temperature: 0.2,
            responseFormat: .init(type: "json_object")
        )

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Parsing

    static func parseTasks(from data: Data) throws -> [TaskItem] {
        guard
            let completion = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = completion.choices.first?.message.content
        else {
            throw OpenAIServiceError.invalidResponse
        }
        return try parseTasks(fromContent: content)
    }

    static func parseTasks(fromContent content: String) throws -> [TaskItem] {
        let json = stripCodeFences(content)
        guard
            let jsonData = json.data(using: .utf8),
            let payload = try? JSONDecoder().decode(TasksPayload.self, from: jsonData)
        else {
            throw OpenAIServiceError.invalidResponse
        }

        return payload.tasks.compactMap { extracted in
            guard let title = extracted.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                return nil
            }
            return TaskItem(
                title: title,
                priority: Priority(fromAI: extracted.priority),
                dueDate: extracted.dueDate.flatMap { dateFormatter.date(from: $0) }
            )
        }
    }

    private static func stripCodeFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            result = result
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - DTOs

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

/// Decodes tolerantly: a malformed entry (missing title, wrong types, not an object) is skipped
/// instead of discarding the whole response. Only a missing/invalid top-level `tasks` array fails.
struct TasksPayload: Decodable {
    struct ExtractedTask: Decodable {
        let title: String?
        let priority: String?
        let dueDate: String?

        enum CodingKeys: String, CodingKey {
            case title, priority, dueDate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            priority = try? container.decodeIfPresent(String.self, forKey: .priority)
            dueDate = try? container.decodeIfPresent(String.self, forKey: .dueDate)
        }
    }

    private struct SkippedEntry: Decodable {
        init(from decoder: Decoder) throws {}
    }

    enum CodingKeys: String, CodingKey {
        case tasks
    }

    let tasks: [ExtractedTask]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var list = try container.nestedUnkeyedContainer(forKey: .tasks)
        var tasks: [ExtractedTask] = []
        while !list.isAtEnd {
            if let task = try? list.decode(ExtractedTask.self) {
                tasks.append(task)
            } else if (try? list.decode(SkippedEntry.self)) == nil {
                break
            }
        }
        self.tasks = tasks
    }
}
