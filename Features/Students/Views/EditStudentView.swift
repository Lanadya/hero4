import SwiftUI

struct EditStudentView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool

    // State variables
    @State private var firstName: String
    @State private var lastName: String
    @State private var notes: String
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var isSaving: Bool = false

    @State private var activeAlert: AlertType?

//    // Alert handling with enum to manage multiple alerts properly
//    enum ActiveAlert: Identifiable {
//        case delete, archive
//
//        var id: Int {
//            switch self {
//            case .delete: return 0
//            case .archive: return 1
//            }
//        }
//    }
//    @State private var activeAlert: ActiveAlert?

    // Initialization
    init(student: Student, viewModel: StudentsViewModel, isPresented: Binding<Bool>) {
        self.student = student
        self.viewModel = viewModel
        self._isPresented = isPresented

        _firstName = State(initialValue: student.firstName)
        _lastName = State(initialValue: student.lastName)
        _notes = State(initialValue: student.notes ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        // Name fields
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vorname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Vorname", text: $firstName)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nachname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Nachname", text: $lastName)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }

                        // Notes field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notizen (optional):")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextEditor(text: $notes)
                                .frame(height: 60)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .foregroundColor(.primary)
                        }

                        // Date and class info
                        HStack {
                            // Entry date
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Erfasst am:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(formatDateOnly(student.entryDate))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // Current class
                            if let classObj = viewModel.dataStore.getClass(id: student.classId) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Klasse:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(classObj.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.vertical, 2)

                        // Class change button
                        if viewModel.classes.count > 1 {
                            Button(action: {
                                // Instead of trying to open the new view directly,
                                // just signal to the parent that we want to switch views
                                isPresented = false  // Close this view

                                // Send a notification that the parent view can listen for
                                NotificationCenter.default.post(
                                    name: Notification.Name("OpenClassChangeView"),
                                    object: nil,
                                    userInfo: ["studentId": student.id.uuidString]
                                )
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                    Text("In andere Klasse verschieben")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }

                        // Error message
                        if showValidationError {
                            Text(validationErrorMessage)
                                .foregroundColor(.red)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }

                // Action buttons
                VStack(spacing: 10) {
                    // Save button
                    Button(action: {
                        saveStudent()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Speichern")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSaving)

                    HStack(spacing: 10) {
                        // Archive button
                        Button(action: {
                            activeAlert = .archive
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "archivebox.fill")
                                Text("Archivieren")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)

                        // Delete button
                        Button(action: {
                            print("DEBUG: Löschen-Button geklickt")
                            activeAlert = .delete
                            print("DEBUG: Delete alert activated")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text("Löschen")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)
                    }

                    // Cancel button
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Abbrechen")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(Color(.systemBackground))
            }
            .navigationBarTitle("Schüler bearbeiten", displayMode: .inline)
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .delete:
                    return Alert(
                        title: Text("Schüler löschen"),
                        message: Text("Möchten Sie den Schüler \(student.fullName) wirklich löschen? Dies kann nicht rückgängig gemacht werden."),
                        primaryButton: .destructive(Text("Löschen")) {
                            print("DEBUG: Löschen-Button im Alert gedrückt für Schüler \(student.id)")
                            deleteStudent()
                        },
                        secondaryButton: .cancel(Text("Abbrechen"))
                    )
                case .archive:
                    return Alert(
                        title: Text("Schüler archivieren"),
                        message: Text("Möchten Sie den Schüler \(student.fullName) wirklich archivieren? Die Noten bleiben im Archiv erhalten."),
                        primaryButton: .default(Text("Archivieren")) {
                            archiveStudent()
                        },
                        secondaryButton: .cancel(Text("Abbrechen"))
                    )
                default:
                        // Handle other cases or provide a default alert
                        return Alert(title: Text(""), message: Text(""), dismissButton: .default(Text("OK")))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // Format date without time
    private func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    // Validate form inputs
    private func validateInputs() -> Bool {
        if firstName.isEmpty && lastName.isEmpty {
            showError("Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
            return false
        }
        return true
    }

    // Show error message
    private func showError(_ message: String) {
        validationErrorMessage = message
        showValidationError = true
    }

    // Format date with time
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    // Save student
    private func saveStudent() {
        guard validateInputs() else { return }

        isSaving = true

        var updatedStudent = student
        updatedStudent.firstName = firstName
        updatedStudent.lastName = lastName
        updatedStudent.notes = notes.isEmpty ? nil : notes

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.viewModel.updateStudent(updatedStudent)
            if self.viewModel.showError {
                self.isSaving = false
            } else {
                self.isSaving = false
                self.isPresented = false
            }
        }
    }

    // Archive student
    private func archiveStudent() {
        isSaving = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.viewModel.archiveStudentWithStatus(self.student)
            self.isSaving = false
            // Modal schließen
            self.isPresented = false
        }
    }

    // Delete student
    private func deleteStudent() {
        print("DEBUG: deleteStudent()-Methode aufgerufen für ID: \(student.id)")

        // Verwende die neue StatusManager-Methode
        viewModel.deleteStudentWithStatus(id: student.id)

        // Modal schließen
        isPresented = false
        print("DEBUG: Modal geschlossen")
    }
}

