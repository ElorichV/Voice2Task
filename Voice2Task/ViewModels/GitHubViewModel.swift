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
    /// Ignores responses from superseded loads (e.g. the user changed the repo mid-request).
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var loadedRepositoryKey: String?

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

    /// Identifies whose issues are in `issues`.
    var repositoryKey: String {
        "\(owner)/\(repo)/\(useMockData)"
    }

    func isSyncing(_ task: TaskItem) -> Bool {
        syncingTaskIDs.contains(task.id)
    }

    // MARK: - Acciones

    func loadIssues() async {
        let key = repositoryKey
        if key != loadedRepositoryKey {
            issues = []
        }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        do {
            let fetched = try await service.listIssues(owner: owner, repo: repo, token: token.isEmpty ? nil : token)
            guard generation == loadGeneration else { return }
            issues = fetched
            loadedRepositoryKey = key
        } catch {
            guard generation == loadGeneration else { return }
            // Never leave another repository's issues on screen after a failed load.
            issues = []
            loadedRepositoryKey = nil
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

        let issue: GitHubIssue
        let reusedExisting: Bool
        do {
            if let existing = await existingIssue(for: task) {
                issue = existing
                reusedExisting = true
            } else {
                issue = try await service.createIssue(
                    owner: owner,
                    repo: repo,
                    title: task.title,
                    body: Self.issueBody(for: task),
                    token: token
                )
                reusedExisting = false
            }
        } catch {
            syncErrorMessage = error.localizedDescription
            return false
        }

        if repositoryKey == loadedRepositoryKey {
            issues.removeAll { $0.id == issue.id }
            issues.insert(issue, at: 0)
        }

        do {
            try tasksViewModel.markAsSynced(task, issueNumber: issue.number)
        } catch {
            syncErrorMessage = "El issue #\(issue.number) está en GitHub, pero no se pudo guardar el vínculo en el dispositivo "
                + "(\(error.localizedDescription)). Si vuelves a subir la tarea, se vinculará al mismo issue sin duplicarlo."
            return false
        }
        syncSuccessMessage = reusedExisting
            ? "Tarea vinculada al issue #\(issue.number) que ya existía en GitHub."
            : "Issue #\(issue.number) creado en GitHub."
        return true
    }

    /// An open issue previously created for this task (found by the marker in its body), e.g. when the
    /// local "synced" flag failed to persist after creation. Prevents duplicate issues on retry.
    private func existingIssue(for task: TaskItem) async -> GitHubIssue? {
        let marker = Self.issueMarker(for: task)
        let candidates = (try? await service.listIssues(owner: owner, repo: repo, token: token.isEmpty ? nil : token)) ?? issues
        return candidates.first { $0.body?.contains(marker) == true }
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
        lines.append(issueMarker(for: task))
        return lines.joined(separator: "\n")
    }

    /// Hidden in GitHub's rendered Markdown.
    static func issueMarker(for task: TaskItem) -> String {
        "<!-- voice2task-id: \(task.id.uuidString) -->"
    }
}
