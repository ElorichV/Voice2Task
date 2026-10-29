import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            placeholder("Grabar", systemImage: "mic")
                .tabItem { Label("Grabar", systemImage: "mic") }

            placeholder("Tareas", systemImage: "checklist")
                .tabItem { Label("Tareas", systemImage: "checklist") }

            placeholder("GitHub", systemImage: "arrow.triangle.2.circlepath")
                .tabItem { Label("GitHub", systemImage: "arrow.triangle.2.circlepath") }
        }
    }

    private func placeholder(_ title: String, systemImage: String) -> some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Próximamente"))
                .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
