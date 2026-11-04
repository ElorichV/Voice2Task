import SwiftUI

struct SettingsView: View {
    @Environment(GitHubViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
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
                    Text("Procesamiento")
                } footer: {
                    Text("Sin API key, Voice2Task usa Apple Intelligence o su IA local sin conexión. El modo demo simula GitHub y la grabación.")
                }

                Section {
                    Button("Ver bienvenida otra vez") {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            hasSeenOnboarding = false
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
