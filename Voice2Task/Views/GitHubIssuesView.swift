import SwiftUI

struct GitHubIssuesView: View {
    @Environment(GitHubViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section {
                    TextField("Owner (usuario u organización)", text: $viewModel.owner)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Repositorio", text: $viewModel.repo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token de GitHub", text: $viewModel.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Repositorio")
                } footer: {
                    Text("El token es opcional para ver issues de repos públicos, pero necesario para crearlos (permiso Issues: lectura y escritura).")
                }

                Section {
                    SecureField("API key de OpenAI", text: $viewModel.openAIAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Modo demo (datos de prueba)", isOn: $viewModel.useMockData)
                } header: {
                    Text("Configuración")
                } footer: {
                    Text("El modo demo simula OpenAI y GitHub para presentar la app sin conexión.")
                }

                Section("Issues abiertos") {
                    issuesContent
                }
            }
            .navigationTitle("GitHub")
            .refreshable { await viewModel.loadIssues() }
            .toolbar {
                Button {
                    Task { await viewModel.loadIssues() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || !(viewModel.isRepositoryConfigured || viewModel.useMockData))
                .accessibilityLabel("Recargar issues")
            }
            .task(id: reloadKey) {
                // Debounce while the user types the owner/repo.
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, viewModel.isRepositoryConfigured || viewModel.useMockData else { return }
                await viewModel.loadIssues()
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
            Text("Configura el owner y el repositorio para ver sus issues.")
                .foregroundStyle(.secondary)
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
        "\(viewModel.owner)/\(viewModel.repo)/\(viewModel.useMockData)"
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
