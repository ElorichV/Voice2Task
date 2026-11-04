import SwiftData
import SwiftUI

@MainActor
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let task: TaskItem?
    @State private var title: String
    @State private var priority: Priority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var saveError: String?

    init(task: TaskItem? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _priority = State(initialValue: task?.priority ?? .media)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarea") {
                    TextField("Título", text: $title, axis: .vertical)
                        .lineLimit(1...3)

                    Picker("Prioridad", selection: $priority) {
                        ForEach(Priority.allCases) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Fecha límite", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Fecha y hora",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle(task == nil ? "Nueva tarea" : "Editar tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("No se pudo guardar", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func save() {
        let savedTask = task ?? TaskItem(title: title)
        savedTask.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        savedTask.priority = priority
        savedTask.dueDate = hasDueDate ? dueDate : nil

        if task == nil {
            modelContext.insert(savedTask)
        }

        ReminderService.cancel(for: savedTask)
        do {
            try modelContext.save()
            Task { await ReminderService.schedule(for: savedTask) }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}
