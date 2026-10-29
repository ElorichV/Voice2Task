import Foundation

struct GitHubIssue: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlURL: URL?
    let createdAt: Date?
    /// Present only when the "issue" is actually a pull request.
    let pullRequest: PullRequestRef?

    struct PullRequestRef: Codable, Hashable {
        let url: URL?
    }

    var isPullRequest: Bool { pullRequest != nil }

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case pullRequest = "pull_request"
    }
}

extension GitHubIssue {
    static let mockIssues: [GitHubIssue] = [
        GitHubIssue(id: 1, number: 1, title: "Preparar demo del pitch", body: "Creado desde Voice2Task", state: "open", htmlURL: nil, createdAt: .now, pullRequest: nil),
        GitHubIssue(id: 2, number: 2, title: "Revisar integración con OpenAI", body: nil, state: "open", htmlURL: nil, createdAt: .now, pullRequest: nil),
    ]
}
