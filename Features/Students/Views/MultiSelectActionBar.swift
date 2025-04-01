import Foundation
import SwiftUI
// Import the centralized color definitions from ColorExtensions.swift directly
// until proper module system is set up

/// A custom action bar that handles batch operations on multiple selected students
struct MultiSelectActionBar: View {
    // MARK: - Properties

    // Required bindings from parent view
    @Binding var selectedStudents: Set<UUID>
    @Binding var showClassChangeForSelectedStudents: Bool
    @Binding var editMode: EditMode

    // Diese Callbacks werden nicht mehr benötigt, aber wir behalten sie für die Abwärtskompatibilität bei
    // Die Aktionen werden jetzt direkt in dieser Komponente behandelt, nicht vom Parent
    let onDeleteTapped: () -> Void
    let onArchiveTapped: () -> Void

    // ViewModel for data operations
    @ObservedObject var viewModel: StudentsViewModel

    // Internal state
    @State private var isProcessing = false
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false

    // MARK: - View Body

    var body: some View {
        VStack {
            Divider()

            HStack(spacing: 16) {
                // Delete button - direkt mit Alert verbunden, ohne zusätzliches Modal
                Button(action: {
                    print("DEBUG MultiSelectActionBar: Delete button clicked")
                    if !selectedStudents.isEmpty && !isProcessing {
                        // Direkt Alert anzeigen, ohne Zwischenfenster
                        showDeleteAlert()
                    }
                }) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                        Text("Löschen")
                            .font(.caption)
                    }
                    .frame(minWidth: 60)
                    .foregroundColor(selectedStudents.isEmpty || isProcessing ? .gray : .red)
                }
                .disabled(selectedStudents.isEmpty || isProcessing)
                .buttonStyle(PlainButtonStyle())

                // Archive button - direkt mit Alert verbunden
                Button(action: {
                    print("DEBUG MultiSelectActionBar: Archive button clicked")
                    if !selectedStudents.isEmpty && !isProcessing {
                        // Direkt Alert anzeigen, ohne Zwischenfenster
                        showArchiveAlert()
                    }
                }) {
                    VStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 18))
                        Text("Archivieren")
                            .font(.caption)
                    }
                    .frame(minWidth: 60)
                    .foregroundColor(selectedStudents.isEmpty || isProcessing ? .gray : .orange)
                }
                .disabled(selectedStudents.isEmpty || isProcessing)
                .buttonStyle(PlainButtonStyle())

                // Class change button
                Button(action: {
                    if !selectedStudents.isEmpty && !isProcessing {
                        showClassChangeForSelectedStudents = true
                    }
                }) {
                    VStack {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 18))
                        Text("Klasse ändern")
                            .font(.caption)
                    }
                    .frame(minWidth: 60)
                    .foregroundColor(selectedStudents.isEmpty || isProcessing ? .gray : .blue)
                }
                .disabled(selectedStudents.isEmpty || isProcessing)
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("\(selectedStudents.count) ausgewählt")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 8)

                Button(action: {
                    editMode = .inactive
                    selectedStudents.removeAll()
                }) {
                    Text("Beenden")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .disabled(isProcessing)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(
                Group {
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Verarbeite...")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                        }
                    }
                }
            )
        }
        // Alerts direkt in dieser View, ohne zusätzliches Modal
        .alert("Schüler löschen", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                executeDeleteOperation()
            }
        } message: {
            Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen? Diese Aktion kann nicht rückgängig gemacht werden und alle zugehörigen Daten (Noten, Sitzpositionen) werden ebenfalls gelöscht.")
        }
        .alert("Schüler archivieren", isPresented: $showArchiveConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Archivieren") {
                executeArchiveOperation()
            }
        } message: {
            Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") archivieren? Archivierte Schüler und deren Bewertungen werden in der regulären Ansicht nicht mehr angezeigt, können aber im Archiv-Tab eingesehen werden.")
        }
    }
    
    // MARK: - Hilfsfunktionen für Alerts
    
    private func showDeleteAlert() {
        showDeleteConfirmation = true
    }
    
    private func showArchiveAlert() {
        showArchiveConfirmation = true
    }
    
    // MARK: - Operationsfunktionen
    
    private func executeDeleteOperation() {
        print("DEBUG MultiSelectActionBar: Löschvorgang für \(selectedStudents.count) Schüler startet")
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
            
            // WICHTIG: Nach erfolgreicher Operation die Auswahl zurücksetzen und den Bearbeitungsmodus beenden
            if success {
                selectedStudents.removeAll()
                editMode = .inactive
            }
            
            print("DEBUG MultiSelectActionBar: Löschvorgang abgeschlossen, Erfolg: \(success)")
            NotificationCenter.default.post(
                name: Notification.Name("StudentOperationCompleted"),
                object: nil,
                userInfo: ["success": success]
            )
        }
    }
    
    private func executeArchiveOperation() {
        print("DEBUG MultiSelectActionBar: Archivierungsvorgang für \(selectedStudents.count) Schüler startet")
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
            
            // WICHTIG: Nach erfolgreicher Operation die Auswahl zurücksetzen und den Bearbeitungsmodus beenden
            if success {
                selectedStudents.removeAll()
                editMode = .inactive
            }
            
            print("DEBUG MultiSelectActionBar: Archivierungsvorgang abgeschlossen, Erfolg: \(success)")
            NotificationCenter.default.post(
                name: Notification.Name("StudentOperationCompleted"),
                object: nil,
                userInfo: ["success": success]
            )
        }
    }
}
