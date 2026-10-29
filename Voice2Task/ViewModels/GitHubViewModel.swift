import Foundation
import Observation

@MainActor
@Observable
final class GitHubViewModel {
    // MARK: - Configuración (persistida en UserDefaults)

    var owner: String {
        didSet { defaults.set(owner, forKey: Constants.Keys.githubOwner) }
    }

    var repo: String {
        didSet { defaults.set(repo, forKey: Constants.Keys.githubRepo) }
    }

    var token: String {
        didSet { defaults.set(token, forKey: Constants.Keys.githubToken) }
    }

    var openAIAPIKey: String {
        didSet { defaults.set(openAIAPIKey, forKey: Constants.Keys.openAIAPIKey) }
    }

    var useMockData: Bool {
        didSet { defaults.set(useMockData, forKey: Constants.Keys.useMockData) }
    }

    // MARK: - Estado

    private(set) var issues: [GitHubIssue] = []
    private(set) var isLoading = false
    private(set) var syncingTaskIDs: Set<UUID> = []
    /// Errors loading issues (shown in the GitHub tab).
    var errorMessage: String?
    /// Result of syncing a task (shown in the Tasks tab).
    var syncErrorMessage: String?
    var syncSuccessMessage: String?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        owner = Constants.githubOwner
        repo = Constants.githubRepo
        token = Constants.githubToken
        openAIAPIKey = Constants.openAIAPIKey
        useMockData = defaults.bool(forKey: Constants.Keys.useMockData)
    }

    var isRepositoryConfigured: Bool {
        !owner.trimmingCharacters(in: .whitespaces).isEmpty && !repo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canSync: Bool {
        Constants.useMockData || (isRepositoryConfigured && !token.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func isSyncing(_ task: TaskItem) -> Bool {
        syncingTaskIDs.contains(task.id)
    }

    // MARK: - Acciones

    func loadIssues() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            issues = try await service.listIssues(owner: owner, repo: repo, token: token.isEmpty ? nil : token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Creates a GitHub issue for the task and marks it as synced. Returns `true` on success.
    @discardableResult
    func sync(_ task: TaskItem, tasksViewModel: TasksViewModel) async -> Bool {
        guard !task.syncedToGitHub, !syncingTaskIDs.contains(task.id) else { return false }
        guard canSync else {
            syncErrorMessage = "Configura el owner, el repo y el token en la pestaña GitHub (o activa el modo demo)."
            return false
        }
        syncingTaskIDs.insert(task.id)
        defer { syncingTaskIDs.remove(task.id) }

        do {
            let issue = try await service.createIssue(
                owner: owner,
                repo: repo,
                title: task.title,
                body: Self.issueBody(for: task),
                token: token
            )
            tasksViewModel.markAsSynced(task, issueNumber: issue.number)
            issues.insert(issue, at: 0)
            syncSuccessMessage = "Issue #\(issue.number) creado en GitHub."
            return true
        } catch {
            syncErrorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Private

    private var service: GitHubService {
        GitHubService(useMockData: Constants.useMockData)
    }

    static func issueBody(for task: TaskItem) -> String {
        var lines = ["**Prioridad:** \(task.priority.displayName)"]
        if let dueDate = task.dueDate {
            lines.append("**Fecha límite:** \(dueDate.formatted(date: .long, time: .omitted))")
        }
        lines.append("")
        lines.append("_Creado desde Voice2Task_")
        return lines.joined(separator: "\n")
    }
}
