import SwiftUI

struct OnboardingView: View {
    @Environment(GitHubViewModel.self) private var gitHubViewModel

    let onComplete: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                pageContent(
                    title: "Habla, Voice2Task escucha",
                    message: "Dicta todo lo que tienes pendiente, como se lo contarías a un compañero.",
                    showsBear: true
                )
                .tag(0)

                pageContent(
                    title: "La IA lo convierte en tareas",
                    message: "Detecta prioridades y fechas: «es urgente», «mañana», «el viernes». Funciona sin conexión."
                )
                .tag(1)

                pageContent(
                    title: "Tu equipo lo ve en GitHub",
                    message: "Sube cada tarea como issue con un toque."
                )
                .tag(2)
            }
            .tabViewStyle(.page)

            if page == 2 {
                VStack(spacing: 12) {
                    Button("Empezar", action: onComplete)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                    Button("Probar con datos de demo") {
                        gitHubViewModel.useMockData = true
                        onComplete()
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Desliza para continuar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .background(Color.accentColor.opacity(0.035).ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func pageContent(title: String, message: String, showsBear: Bool = false) -> some View {
        VStack(spacing: 24) {
            Spacer()
            if showsBear {
                BearMascotView(size: 190, mood: .listening)
                    .padding(.bottom, 12)
            } else {
                Image(systemName: title.hasPrefix("La IA") ? "sparkles" : "arrow.up.circle")
                    .font(.system(size: 76, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 202)
            }
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
