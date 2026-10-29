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
    /// True after an AI failure, so the UI can offer demo data for the pitch.
    private(set) var canOfferMockFallback = false

    @ObservationIgnored private let modelContext: ModelContext
    private var errorMessage: String?

    init(modelContext: ModelContext, audioService: AudioService? = nil) {
        self.modelContext = modelContext
        self.audioService = audioService ?? AudioService()
    }

    var transcribedText: String { audioService.transcribedText }
    var isRecording: Bool { audioService.isRecording }
    var isFinalizingTranscription: Bool { audioService.isFinalizing }

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
        do {
            try await audioService.startRecording()
        } catch {
            errorMessage = error.localizedDescription
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
            let tasks = try await OpenAIService().extractTasks(from: text)
            save(tasks)
        } catch {
            errorMessage = error.localizedDescription
            canOfferMockFallback = true
        }
    }

    private func save(_ tasks: [TaskItem]) {
        for task in tasks {
            modelContext.insert(task)
        }
        do {
            try modelContext.save()
            lastExtractedTasks = tasks
        } catch {
            errorMessage = "No se pudieron guardar las tareas: \(error.localizedDescription)"
        }
    }
}
