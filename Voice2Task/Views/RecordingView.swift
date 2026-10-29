import SwiftUI

struct RecordingView: View {
    @Environment(RecordingViewModel.self) private var viewModel
    @State private var showManualInput = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    recordButton
                    transcriptionCard
                    processButton

                    if !viewModel.lastExtractedTasks.isEmpty {
                        extractedTasksCard
                    }

                    manualInput(text: $viewModel.manualText)
                }
                .padding()
            }
            .navigationTitle("Grabar")
            .toolbar {
                if !viewModel.transcribedText.isEmpty || !viewModel.lastExtractedTasks.isEmpty {
                    Button("Limpiar") { viewModel.reset() }
                        .disabled(viewModel.isRecording || viewModel.isProcessing)
                }
            }
            .alert("Algo salió mal", isPresented: alertBinding) {
                if viewModel.canOfferMockFallback {
                    Button("Usar datos de prueba") { viewModel.useMockTasks() }
                }
                Button("OK", role: .cancel) { viewModel.dismissAlert() }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var recordButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.toggleRecording()
                    if viewModel.alertMessage != nil && !viewModel.isRecording {
                        withAnimation { showManualInput = true }
                    }
                }
            } label: {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(viewModel.isRecording ? Color.red : Color.accentColor, in: Circle())
                    .shadow(color: (viewModel.isRecording ? Color.red : Color.accentColor).opacity(0.4), radius: 12, y: 6)
                    .symbolEffect(.pulse, isActive: viewModel.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            .accessibilityLabel(viewModel.isRecording ? "Detener grabación" : "Empezar a grabar")

            Text(viewModel.isRecording ? "Escuchando… toca para detener" : "Toca para grabar una nota de voz")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var transcriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcripción", systemImage: "text.quote")
                .font(.headline)

            ScrollView {
                Text(viewModel.transcribedText.isEmpty ? "Aquí aparecerá lo que digas en tiempo real." : viewModel.transcribedText)
                    .foregroundStyle(viewModel.transcribedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 100, maxHeight: 220)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var processButton: some View {
        Button {
            Task { await viewModel.processTranscription() }
        } label: {
            HStack {
                if viewModel.isProcessing || viewModel.isFinalizingTranscription {
                    ProgressView()
                        .tint(.white)
                }
                Label(processButtonTitle, systemImage: "sparkles")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canProcess)
    }

    private var processButtonTitle: String {
        if viewModel.isProcessing { return "Procesando…" }
        if viewModel.isFinalizingTranscription { return "Finalizando transcripción…" }
        if viewModel.isRecording { return "Detén la grabación para procesar" }
        return "Procesar con IA"
    }

    private var extractedTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Se agregaron \(viewModel.lastExtractedTasks.count) tareas", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            ForEach(viewModel.lastExtractedTasks) { task in
                HStack {
                    Text(task.title)
                    Spacer()
                    PriorityBadge(priority: task.priority)
                }
            }

            Text("Revísalas en la pestaña Tareas.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func manualInput(text: Binding<String>) -> some View {
        DisclosureGroup(isExpanded: $showManualInput) {
            VStack(spacing: 12) {
                TextField("Escribe o pega tu texto…", text: text, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await viewModel.processManualText(viewModel.manualText) }
                } label: {
                    Label("Procesar texto", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canProcessManualText)
            }
            .padding(.top, 8)
        } label: {
            Label("¿Falló el audio? Pega tu texto aquí", systemImage: "keyboard")
                .font(.subheadline.weight(.medium))
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.dismissAlert() } }
        )
    }
}

#if DEBUG
#Preview {
    RecordingView()
        .withPreviewEnvironment()
}
#endif
