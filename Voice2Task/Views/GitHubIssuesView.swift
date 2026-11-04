import SwiftUI

struct GitHubIssuesView: View {
    @Environment(GitHubViewModel.self) private var viewModel
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Issues abiertos") {
                    issuesContent
                }
            }
            .navigationTitle("GitHub")
            .refreshable { await viewModel.loadIssues() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Ajustes")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadIssues() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading || !(viewModel.isRepositoryConfigured || viewModel.useMockData))
                    .accessibilityLabel("Recargar issues")
                }
            }
            .task(id: reloadKey) {
                // Debounce while the user types the owner/repo.
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, viewModel.isRepositoryConfigured || viewModel.useMockData else { return }
                await viewModel.loadIssues()
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .alert("Error de GitHub", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var issuesContent: some View {
        if viewModel.isLoading && viewModel.issues.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if !(viewModel.isRepositoryConfigured || viewModel.useMockData) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configura el owner y el repositorio para ver sus issues.")
                    .foregroundStyle(.secondary)
                Button("Configurar") { isSettingsPresented = true }
            }
        } else if viewModel.issues.isEmpty {
            Text("No hay issues abiertos.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(viewModel.issues) { issue in
                if let url = issue.htmlURL {
                    Link(destination: url) { issueRow(issue) }
                        .foregroundStyle(.primary)
                } else {
                    issueRow(issue)
                }
            }
        }
    }

    private func issueRow(_ issue: GitHubIssue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("#\(issue.number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(issue.title)
                .lineLimit(2)
            Spacer(minLength: 0)
            if issue.htmlURL != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reloadKey: String {
        "\(viewModel.repositoryKey)/\(viewModel.token)"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#if DEBUG
#Preview {
    GitHubIssuesView()
        .withPreviewEnvironment()
}
#endif
