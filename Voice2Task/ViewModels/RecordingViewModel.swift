import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class RecordingViewModel {
    let audioService: AudioService

    var manualText = ""
    private(set) var isProcessing = false
    private(set) var lastExtractedTasks: [TaskItem] = []
    private(set) var tasksAddedCount = 0
    private(set) var recordingStartCount = 0
    private(set) var errorCount = 0
    private(set) var lastEngine: ExtractionEngine?
    /// True after an AI failure, so the UI can offer demo data for the pitch.
    private(set) var canOfferMockFallback = false

    @ObservationIgnored private let modelContext: ModelContext
    private var errorMessage: String?

    init(modelContext: ModelContext, audioService: AudioService? = nil) {
        self.modelContext = modelContext
        self.audioService = audioService ?? AudioService()
    }

    var transcribedText: String { audioService.transcribedText }
    var audioLevel: Float { audioService.audioLevel }
    var isRecording: Bool { audioService.isRecording }
    var isFinalizingTranscription: Bool { audioService.isFinalizing }
    var isDemoMode: Bool { Constants.useMockData }

    /// Only after recording stops and the final transcript has arrived, so trailing words aren't dropped.
    var canProcess: Bool {
        !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isRecording
            && !isFinalizingTranscription
            && !isProcessing
    }

    var canProcessManualText: Bool {
        !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    var alertMessage: String? { errorMessage ?? audioService.errorMessage }

    func dismissAlert() {
        errorMessage = nil
        audioService.errorMessage = nil
        canOfferMockFallback = false
    }

    // MARK: - Recording

    func toggleRecording() async {
        if isRecording {
            audioService.stopRecording()
            return
        }
        lastExtractedTasks = []
        if isDemoMode {
            audioService.startSimulatedRecording()
            recordingStartCount += 1
            return
        }
        do {
            try await audioService.startRecording()
            recordingStartCount += 1
        } catch {
            errorMessage = error.localizedDescription
            errorCount += 1
        }
    }

    // MARK: - AI processing

    func processTranscription() async {
        guard canProcess else { return }
        await process(text: transcribedText)
    }

    /// Fallback when the microphone or speech recognition isn't available.
    func processManualText(_ text: String) async {
        await process(text: text)
        if errorMessage == nil {
            manualText = ""
        }
    }

    func useMockTasks() {
        dismissAlert()
        save(TaskItem.mockTasks)
    }

    func reset() {
        audioService.reset()
        manualText = ""
        lastExtractedTasks = []
        lastEngine = nil
        dismissAlert()
    }

    private func process(text: String) async {
        guard !isProcessing else { return }
        if isRecording {
            audioService.stopRecording()
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await TaskExtractionService().extractTasks(from: text)
            save(result.tasks, engine: result.engine)
        } catch {
            errorMessage = error.localizedDescription
            errorCount += 1
            canOfferMockFallback = true
        }
    }

    private func save(_ tasks: [TaskItem], engine: ExtractionEngine? = nil) {
        for task in tasks {
            modelContext.insert(task)
        }
        do {
            try modelContext.save()
            lastExtractedTasks = tasks
            tasksAddedCount += tasks.count
            lastEngine = engine
            for task in tasks {
                Task { await ReminderService.schedule(for: task) }
            }
        } catch {
            errorMessage = "No se pudieron guardar las tareas: \(error.localizedDescription)"
            errorCount += 1
        }
    }
}
