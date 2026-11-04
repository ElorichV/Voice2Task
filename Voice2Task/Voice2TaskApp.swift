import SwiftData
import SwiftUI
import UserNotifications

@main
struct Voice2TaskApp: App {
    let modelContainer: ModelContainer
    private let notificationDelegate: ReminderNotificationDelegate
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var recordingViewModel: RecordingViewModel
    @State private var tasksViewModel: TasksViewModel
    @State private var gitHubViewModel: GitHubViewModel

    init() {
        let notificationDelegate = ReminderNotificationDelegate()
        self.notificationDelegate = notificationDelegate
        UNUserNotificationCenter.current().delegate = notificationDelegate

        let container = AppModelContainer.shared
        modelContainer = container
        _recordingViewModel = State(initialValue: RecordingViewModel(modelContext: container.mainContext))
        _tasksViewModel = State(initialValue: TasksViewModel(modelContext: container.mainContext))
        _gitHubViewModel = State(initialValue: GitHubViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fullScreenCover(isPresented: onboardingBinding) {
                    OnboardingView { hasSeenOnboarding = true }
                }
                .environment(recordingViewModel)
                .environment(tasksViewModel)
                .environment(gitHubViewModel)
        }
        .modelContainer(modelContainer)
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )
    }
}
