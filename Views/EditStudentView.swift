
import SwiftUI

struct EditStudentView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool

    // State-Variablen
    @State private var firstName: String
    @State private var lastName: String
    @State private var notes: String
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var isSaving: Bool = false
    @State private var showClassChangeModal = false

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
                // Hauptinhalt
                ScrollView {
                    VStack(spacing: 16) {
                        // Namensfelder
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vorname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Vorname", text: $firstName)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nachname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Nachname", text: $lastName)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }

                        // Notizen
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notizen (optional):")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextEditor(text: $notes)
                                .frame(height: 80)
                                .padding(5)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .foregroundColor(.primary)
                        }

                        // Infos und Klasse
                        HStack(alignment: .top, spacing: 20) {
                            // Erfassungsdatum
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Erfasst am:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formatDate(student.entryDate))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // Aktuelle Klasse
                            if let classObj = viewModel.dataStore.getClass(id: student.classId) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Aktuelle Klasse:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text(classObj.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Klasse wechseln Button
                        if viewModel.classes.count > 1 {
                            Button(action: {
                                showClassChangeModal = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                    Text("In andere Klasse verschieben")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                        }

                        // Fehlermeldung, wenn vorhanden
                        if showValidationError {
                            Text(validationErrorMessage)
                                .foregroundColor(.red)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                // Aktionsbuttons im gleichen Stil wie die Hilfe-Knöpfe
                VStack(spacing: 12) {
                    // Speichern
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

                    HStack(spacing: 12) {
                        // Archivieren
                        Button(action: {
                            showingArchiveConfirmation = true
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

                        // Löschen
                        Button(action: {
                            showingDeleteConfirmation = true
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

                    // Abbrechen
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
                .padding(.bottom, 20)
                .padding(.top, 8)
                .background(Color(.systemBackground))
            }
            .navigationBarTitle("Schüler bearbeiten", displayMode: .inline)
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Schüler löschen"),
                    message: Text("Möchten Sie den Schüler \(student.fullName) wirklich löschen? Dies kann nicht rückgängig gemacht werden."),
                    primaryButton: .destructive(Text("Löschen")) {
                        deleteStudent()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
            .sheet(isPresented: $showClassChangeModal) {
                ClassChangeView(
                    student: student,
                    viewModel: viewModel,
                    isPresented: $showClassChangeModal
                )
            }
            .alert(isPresented: $showingArchiveConfirmation) {
                Alert(
                    title: Text("Schüler archivieren"),
                    message: Text("Möchten Sie den Schüler \(student.fullName) wirklich archivieren?"),
                    primaryButton: .default(Text("Archivieren")) {
                        archiveStudent()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func validateInputs() -> Bool {
        // Mindestens ein Namensfeld muss ausgefüllt sein
        if firstName.isEmpty && lastName.isEmpty {
            showError("Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
            return false
        }
        return true
    }

    private func showError(_ message: String) {
        validationErrorMessage = message
        showValidationError = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

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

    private func archiveStudent() {
        isSaving = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.viewModel.archiveStudent(self.student)
            self.isSaving = false
            self.isPresented = false
        }
    }

    private func deleteStudent() {
        isSaving = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.viewModel.deleteStudent(id: self.student.id)
            self.isSaving = false
            self.isPresented = false
        }
    }
//    // Die restlichen Funktionen bleiben gleich
//    private func saveStudent() { /* Dein Code */ }
//    private func archiveStudent() { /* Dein Code */ }
//    private func deleteStudent() { /* Dein Code */ }
//    private func validateInputs() -> Bool { /* Dein Code */ }
//    private func showError(_ message: String) { /* Dein Code */ }
//    private func formatDate(_ date: Date) -> String { /* Dein Code */ }
}
