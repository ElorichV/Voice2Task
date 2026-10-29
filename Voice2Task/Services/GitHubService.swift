import Foundation

enum GitHubServiceError: LocalizedError {
    case missingRepository
    case missingToken
    case network(URLError)
    case unauthorized
    case notFound
    case rateLimited
    case validation(String?)
    case http(status: Int, message: String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingRepository:
            "Configura el owner y el repo de GitHub."
        case .missingToken:
            "Necesitas un token de GitHub para crear issues."
        case .network(let error):
            error.friendlyMessage
        case .unauthorized:
            "El token de GitHub no es válido o no tiene permisos sobre este repo."
        case .notFound:
            "No se encontró el repositorio (o es privado y falta el token)."
        case .rateLimited:
            "Se alcanzó el límite de solicitudes de GitHub. Agrega un token o espera un momento."
        case .validation(let message):
            "GitHub rechazó la solicitud" + (message.map { ": \($0)" } ?? ".")
        case .http(let status, let message):
            "Error de GitHub (\(status))" + (message.map { ": \($0)" } ?? "")
        case .invalidResponse:
            "La respuesta de GitHub no tiene el formato esperado."
        }
    }
}

struct GitHubService {
    static let baseURL = URL(string: "https://api.github.com")!

    var useMockData: Bool = Constants.useMockData
    var session: URLSession = .shared

    /// Lists open issues (pull requests are filtered out). The token is optional; public repos work without it.
    func listIssues(owner: String, repo: String, token: String? = nil) async throws -> [GitHubIssue] {
        if useMockData {
            try? await Task.sleep(for: .milliseconds(500))
            return await MockIssueStore.shared.all()
        }

        var components = URLComponents(url: try repoURL(owner: owner, repo: repo, path: "issues"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "50"),
        ]
        guard let url = components?.url else { throw GitHubServiceError.missingRepository }

        let request = makeRequest(url: url, method: "GET", token: token)
        let data = try await send(request)
        do {
            return try Self.decoder.decode([GitHubIssue].self, from: data).filter { !$0.isPullRequest }
        } catch {
            throw GitHubServiceError.invalidResponse
        }
    }

    func createIssue(owner: String, repo: String, title: String, body: String, token: String) async throws -> GitHubIssue {
        if useMockData {
            try? await Task.sleep(for: .milliseconds(500))
            return await MockIssueStore.shared.create(title: title, body: body)
        }

        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw GitHubServiceError.missingToken }

        var request = makeRequest(url: try repoURL(owner: owner, repo: repo, path: "issues"), method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateIssueBody(title: title, body: body))

        let data = try await send(request)
        do {
            return try Self.decoder.decode(GitHubIssue.self, from: data)
        } catch {
            throw GitHubServiceError.invalidResponse
        }
    }

    // MARK: - Private

    private func repoURL(owner: String, repo: String, path: String) throws -> URL {
        let owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !repo.isEmpty else { throw GitHubServiceError.missingRepository }
        return Self.baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(owner)
            .appendingPathComponent(repo)
            .appendingPathComponent(path)
    }

    private func makeRequest(url: URL, method: String, token: String?) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Voice2Task-iOS", forHTTPHeaderField: "User-Agent")
        if let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw GitHubServiceError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GitHubServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GitHubErrorBody.self, from: data))?.message
            switch http.statusCode {
            case 401:
                throw GitHubServiceError.unauthorized
            case 403 where http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0", 429:
                throw GitHubServiceError.rateLimited
            case 403:
                throw GitHubServiceError.unauthorized
            case 404:
                throw GitHubServiceError.notFound
            case 410, 422:
                throw GitHubServiceError.validation(message)
            default:
                throw GitHubServiceError.http(status: http.statusCode, message: message)
            }
        }
        return data
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct CreateIssueBody: Encodable {
    let title: String
    let body: String
}

private struct GitHubErrorBody: Decodable {
    let message: String?
}

/// Demo-mode issue tracker, so issues created during the pitch show up in the GitHub tab (resets on relaunch).
private actor MockIssueStore {
    static let shared = MockIssueStore()

    private var issues = GitHubIssue.mockIssues

    func all() -> [GitHubIssue] {
        issues
    }

    func create(title: String, body: String) -> GitHubIssue {
        let number = (issues.map(\.number).max() ?? 0) + 1
        let issue = GitHubIssue(id: number, number: number, title: title, body: body, state: "open", htmlURL: nil, createdAt: .now, pullRequest: nil)
        issues.insert(issue, at: 0)
        return issue
    }
}
