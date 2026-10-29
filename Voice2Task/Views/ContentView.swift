import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem { Label("Grabar", systemImage: "mic") }

            TasksListView()
                .tabItem { Label("Tareas", systemImage: "checklist") }

            GitHubIssuesView()
                .tabItem { Label("GitHub", systemImage: "arrow.triangle.2.circlepath") }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .withPreviewEnvironment()
}
#endif
