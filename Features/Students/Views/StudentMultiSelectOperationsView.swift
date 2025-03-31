import SwiftUI

struct StudentMultiSelectOperationsView: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudents: Set<UUID>
    @Binding var editMode: EditMode
    @Binding var isPresented: Bool
    @Binding var showClassChangeView: Bool  // Add this binding

    @State private var operationType: OperationType? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    enum OperationType: Identifiable {
        case delete, archive, move

        var id: Int {
            switch self {
            case .delete: return 0
            case .archive: return 1
            case .move: return 2
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(selectedStudents.count) Schüler ausgewählt")
                    .font(.headline)
                Spacer()
                Button("Schließen") {
                    isPresented = false
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            // Operation buttons
            VStack(spacing: 20) {
                // Spacing for visual hierarchy
                Spacer().frame(height: 20)

                // Delete Button
                Button(action: {
                    operationType = .delete
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Schüler löschen")
                                .font(.headline)
                            Text("\(selectedStudents.count) ausgewählte Schüler werden vollständig gelöscht")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                // Archive Button
                Button(action: {
                    operationType = .archive
                }) {
                    HStack {
                        Image(systemName: "archivebox")
                            .font(.title2)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Schüler archivieren")
                                .font(.headline)
                            Text("\(selectedStudents.count) ausgewählte Schüler werden archiviert")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                // Move to Class Button
                Button(action: {
                    operationType = .move
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Klasse wechseln")
                                .font(.headline)
                            Text("\(selectedStudents.count) ausgewählte Schüler in andere Klasse verschieben")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Error message (if any)
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                // Processing indicator
                if isProcessing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Vorgang wird durchgeführt...")
                            .padding(.leading, 8)
                    }
                    .padding()
                }
            }
            .padding()
            .disabled(isProcessing)
        }
        .alert(item: $operationType) { operationType in
            switch operationType {
            case .delete:
                return Alert(
                    title: Text("Schüler löschen"),
                    message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen? Dies kann nicht rückgängig gemacht werden."),
                    primaryButton: .destructive(Text("Löschen")) {
                        executeDeleteOperation()
                    },
                    secondaryButton: .cancel()
                )
            case .archive:
                return Alert(
                    title: Text("Schüler archivieren"),
                    message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") archivieren?"),
                    primaryButton: .default(Text("Archivieren")) {
                        executeArchiveOperation()
                    },
                    secondaryButton: .cancel()
                )
            case .move:
                return Alert(
                    title: Text("Klasse wechseln"),
                    message: Text("Diese Aktion öffnet die Klassenauswahl."),
                    primaryButton: .default(Text("Fortfahren")) {
                        handleClassChangeOperation()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: - Operation Handlers

    private func executeDeleteOperation() {
        print("DEBUG MultiSelectView: Löschvorgang für \(selectedStudents.count) Schüler startet")
        isProcessing = true

        viewModel.deleteMultipleStudentsWithStatus(studentIds: Array(selectedStudents))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            self.isPresented = false
            print("DEBUG MultiSelectView: Löschvorgang abgeschlossen")
            NotificationCenter.default.post(name: Notification.Name("StudentOperationCompleted"), object: nil)
        }
    }

    private func executeArchiveOperation() {
        print("DEBUG MultiSelectView: Archivierungsvorgang für \(selectedStudents.count) Schüler startet")
        isProcessing = true

        viewModel.archiveMultipleStudentsWithStatus(studentIds: Array(selectedStudents))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            self.isPresented = false
            print("DEBUG MultiSelectView: Archivierungsvorgang abgeschlossen")
            NotificationCenter.default.post(name: Notification.Name("StudentOperationCompleted"), object: nil)
        }
    }

    private func handleClassChangeOperation() {
        // Close this view and open the class change view
        isPresented = false
        // Use the binding passed from parent
        showClassChangeView = true
    }
}
