import SwiftUI
import Foundation
// Import the centralized color definitions from ColorExtensions.swift directly
// until proper module system is set up

// Define a local operation type for this view's functionality

struct StudentMultiSelectOperationsView: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudents: Set<UUID>
    @Binding var editMode: EditMode
    @Binding var isPresented: Bool
    @Binding var showClassChangeView: Bool  // Binding for the class change view
    
    // WICHTIG: Wir trennen absichtlich den selectedStudent vom Hauptview,
    // um ungewollte Interaktionen zwischen Einzelauswahl und Multiselect zu vermeiden
    // Wir verwenden hier eine separate Variable nur für die Multiselect-Ansicht

    @State private var operationType: OperationType? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    // View-specific operation type
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
                            .foregroundColor(.heroSecondary)
                        VStack(alignment: .leading) {
                            Text("Klasse wechseln")
                                .font(.headline)
                            Text("Mehrere Schüler in andere Klasse verschieben")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.heroSecondary.opacity(0.1))
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
                    message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen? Diese Aktion kann nicht rückgängig gemacht werden und alle zugehörigen Daten (Noten, Sitzpositionen) werden ebenfalls gelöscht."),
                    primaryButton: .destructive(Text("Löschen")) {
                        print("DEBUG: Delete confirmed in StudentMultiSelectOperationsView")
                        executeDeleteOperation()
                    },
                    secondaryButton: .cancel()
                )
            case .archive:
                return Alert(
                    title: Text("Schüler archivieren"),
                    message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") archivieren? Archivierte Schüler und deren Bewertungen werden in der regulären Ansicht nicht mehr angezeigt, können aber im Archiv-Tab eingesehen werden."),
                    primaryButton: .default(Text("Archivieren")) {
                        print("DEBUG: Archive confirmed in StudentMultiSelectOperationsView")
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
        .onAppear {
            print("DEBUG: MultiSelectOperationsView appeared with operation: \(viewModel.multiSelectOperation)")
            // Automatically set the operation type based on the ViewModel's state
            switch viewModel.multiSelectOperation {
            case .delete:
                print("DEBUG: Setting operationType to .delete")
                DispatchQueue.main.async {
                    self.operationType = .delete
                }
            case .archive:
                print("DEBUG: Setting operationType to .archive")
                DispatchQueue.main.async {
                    self.operationType = .archive
                }
            case .move:
                print("DEBUG: Setting operationType to .move")
                DispatchQueue.main.async {
                    self.operationType = .move
                }
            case .none:
                print("DEBUG: No operation type set")
                // Do nothing, let user select an operation
                break
            }
            
            // Reset ViewModel state after a delay to ensure alert is shown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.multiSelectOperation = .none
            }
        }
    }

    // MARK: - Operation Handlers

    private func executeDeleteOperation() {
        print("DEBUG MultiSelectView: Löschvorgang für \(selectedStudents.count) Schüler startet")
        isProcessing = true

        let success = viewModel.deleteMultipleStudentsWithStatus(studentIds: Array(selectedStudents))
        
        // Mehr Details über den Erfolg oder Misserfolg anzeigen
        let message: String
        if success {
            message = "\(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler wurde" : "Schüler wurden") erfolgreich gelöscht."
        } else {
            message = "Beim Löschen der Schüler ist ein Fehler aufgetreten. Einige oder alle Schüler konnten nicht gelöscht werden."
        }
        
        // Zeige dem Benutzer ein Feedback-Alert
        viewModel.showError(message: message)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
            self.isPresented = false
            print("DEBUG MultiSelectView: Löschvorgang abgeschlossen, Erfolg: \(success)")
            NotificationCenter.default.post(
                name: Notification.Name("StudentOperationCompleted"),
                object: nil,
                userInfo: ["success": success]
            )
        }
    }

    private func executeArchiveOperation() {
        print("DEBUG MultiSelectView: Archivierungsvorgang für \(selectedStudents.count) Schüler startet")
        isProcessing = true

        let success = viewModel.archiveMultipleStudentsWithStatus(studentIds: Array(selectedStudents))
        
        // Mehr Details über den Erfolg oder Misserfolg anzeigen
        let message: String
        if success {
            message = "\(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler wurde" : "Schüler wurden") erfolgreich archiviert."
        } else {
            message = "Beim Archivieren der Schüler ist ein Fehler aufgetreten. Einige oder alle Schüler konnten nicht archiviert werden."
        }
        
        // Zeige dem Benutzer ein Feedback-Alert
        viewModel.showError(message: message)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
            self.isPresented = false
            print("DEBUG MultiSelectView: Archivierungsvorgang abgeschlossen, Erfolg: \(success)")
            NotificationCenter.default.post(
                name: Notification.Name("StudentOperationCompleted"),
                object: nil,
                userInfo: ["success": success]
            )
        }
    }

    private func handleClassChangeOperation() {
        // Close this view and open the class change view
        isPresented = false
        // Use the binding passed from parent
        showClassChangeView = true
    }
}
