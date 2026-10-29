import Foundation

/// Temporary app configuration for the hackathon. Values are read from UserDefaults first
/// (editable from the app), then from the Xcode scheme's environment variables.
enum Constants {
    enum Keys {
        static let openAIAPIKey = "openAIAPIKey"
        static let githubOwner = "githubOwner"
        static let githubRepo = "githubRepo"
        static let githubToken = "githubToken"
        static let useMockData = "useMockData"
    }

    /// Flip to `true` to demo the whole UI without network/API keys (also toggleable in-app via `Keys.useMockData`).
    static let forceMockData = false

    static var useMockData: Bool {
        forceMockData || UserDefaults.standard.bool(forKey: Keys.useMockData)
    }

    static var openAIAPIKey: String {
        value(forKey: Keys.openAIAPIKey, env: "OPENAI_API_KEY")
    }

    static var githubOwner: String {
        value(forKey: Keys.githubOwner, env: "GITHUB_OWNER")
    }

    static var githubRepo: String {
        value(forKey: Keys.githubRepo, env: "GITHUB_REPO")
    }

    static var githubToken: String {
        value(forKey: Keys.githubToken, env: "GITHUB_TOKEN")
    }

    private static func value(forKey key: String, env: String) -> String {
        let stored = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty { return stored }
        return ProcessInfo.processInfo.environment[env]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
