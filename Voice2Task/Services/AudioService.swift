import AVFoundation
import Foundation
import Observation
import Speech

enum AudioServiceError: LocalizedError {
    case recognizerUnavailable
    case speechPermissionDenied
    case microphonePermissionDenied
    case noInputDevice
    case audioSession(Error)
    case audioEngine(Error)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "El reconocimiento de voz no está disponible ahora mismo. Puedes pegar tu texto manualmente."
        case .speechPermissionDenied:
            "Voice2Task no tiene permiso para usar el reconocimiento de voz. Actívalo en Ajustes o pega tu texto manualmente."
        case .microphonePermissionDenied:
            "Voice2Task no tiene permiso para usar el micrófono. Actívalo en Ajustes o pega tu texto manualmente."
        case .noInputDevice:
            "No se encontró un micrófono disponible. Pega tu texto manualmente."
        case .audioSession(let error):
            "No se pudo configurar el audio: \(error.localizedDescription)"
        case .audioEngine(let error):
            "No se pudo iniciar la grabación: \(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class AudioService {
    /// Live transcription, updated as partial results arrive.
    var transcribedText = ""
    private(set) var lastResult: TranscriptionResult?
    private(set) var isRecording = false
    /// True between `stopRecording()` and the recognizer's final result, so callers don't process a partial transcript.
    private(set) var isFinalizing = false
    /// Set when recognition fails mid-recording (errors at start are thrown instead).
    var errorMessage: String?

    @ObservationIgnored private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var isTapInstalled = false
    @ObservationIgnored private var finalizeTimeout: Task<Void, Never>?
    @ObservationIgnored private var simulationTask: Task<Void, Never>?

    /// Dictated word by word in demo mode (matches `TaskItem.mockTasks`).
    static let demoScript = "Hoy tengo que preparar la demo del pitch, es urgente. Esta semana hay que revisar la integración con GitHub. Y cuando haya tiempo, diseñar el ícono de la app."

    func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw AudioServiceError.speechPermissionDenied
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw AudioServiceError.microphonePermissionDenied
        }
    }

    func startRecording() async throws {
        guard !isRecording else { return }
        errorMessage = nil

        try await requestPermissions()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw AudioServiceError.recognizerUnavailable
        }

        tearDown()
        transcribedText = ""
        lastResult = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioServiceError.audioSession(error)
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            deactivateSession()
            throw AudioServiceError.noInputDevice
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        Self.installTap(on: inputNode, format: format, request: request)
        isTapInstalled = true

        recognitionTask = Self.startRecognition(with: speechRecognizer, request: request) { [weak self] text, confidence, isFinal, errorText in
            Task { @MainActor [weak self] in
                self?.handleRecognition(text: text, confidence: confidence, isFinal: isFinal, errorText: errorText)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            tearDown()
            throw AudioServiceError.audioEngine(error)
        }

        isRecording = true
    }

    /// Demo mode: types `script` word by word as if it were being transcribed live. No microphone needed.
    func startSimulatedRecording(script: String = AudioService.demoScript) {
        guard !isRecording else { return }
        tearDown()
        errorMessage = nil
        transcribedText = ""
        lastResult = nil
        isRecording = true

        let words = script.split(separator: " ").map(String.init)
        simulationTask = Task { [weak self] in
            for word in words {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.transcribedText += (self.transcribedText.isEmpty ? "" : " ") + word
            }
            self?.finishSimulation()
        }
    }

    func stopRecording() {
        if simulationTask != nil {
            finishSimulation()
            return
        }
        guard isRecording || isTapInstalled else { return }
        let awaitingFinalResult = recognitionTask != nil
        recognitionRequest?.endAudio()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfNeeded()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        deactivateSession()
        if awaitingFinalResult {
            beginFinalizing()
        }
    }

    func reset() {
        tearDown()
        transcribedText = ""
        lastResult = nil
        errorMessage = nil
    }

    // MARK: - Private

    private func handleRecognition(text: String?, confidence: Double, isFinal: Bool, errorText: String?) {
        if let text, !text.isEmpty {
            transcribedText = text
            lastResult = TranscriptionResult(text: text, confidence: confidence)
        }

        if isFinal || errorText != nil {
            finishFinalizing()
        }

        if let errorText, isRecording {
            // Speech framework reports an error when no speech was detected; keep whatever text we already have.
            if transcribedText.isEmpty {
                errorMessage = "No se pudo transcribir el audio (\(errorText)). Intenta de nuevo o pega tu texto."
            }
            stopRecording()
        } else if isFinal {
            stopRecording()
        }
    }

    private func beginFinalizing() {
        isFinalizing = true
        finalizeTimeout?.cancel()
        // Don't block processing forever if the recognizer never delivers a final result.
        finalizeTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.isFinalizing = false
        }
    }

    private func finishFinalizing() {
        finalizeTimeout?.cancel()
        finalizeTimeout = nil
        isFinalizing = false
    }

    private func finishSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isRecording = false
        if !transcribedText.isEmpty {
            lastResult = TranscriptionResult(text: transcribedText, confidence: 1)
        }
    }

    private func tearDown() {
        simulationTask?.cancel()
        simulationTask = nil
        finishFinalizing()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfNeeded()
        isRecording = false
    }

    private func removeTapIfNeeded() {
        guard isTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        isTapInstalled = false
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Nonisolated so the tap block (called on the audio thread) doesn't inherit main-actor isolation.
    nonisolated private static func installTap(
        on node: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func startRecognition(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (_ text: String?, _ confidence: Double, _ isFinal: Bool, _ errorText: String?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(
                result?.bestTranscription.formattedString,
                averageConfidence(of: result),
                result?.isFinal ?? false,
                error?.localizedDescription
            )
        }
    }

    nonisolated private static func averageConfidence(of result: SFSpeechRecognitionResult?) -> Double {
        guard let segments = result?.bestTranscription.segments, !segments.isEmpty else { return 0 }
        let total = segments.reduce(Float(0)) { $0 + $1.confidence }
        return Double(total / Float(segments.count))
    }
}
