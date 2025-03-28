import SwiftUI

struct AddStudentView: View {
    let classId: UUID
    let className: String
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                // Fehlermeldung oben anzeigen
                            if showValidationError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text(validationErrorMessage)
                                        .foregroundColor(.red)
                                        .padding(.vertical, 6)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }

                // Formular-Bereich
                Form {
                    Section(header: Text("Schüler hinzufügen")) {
                        // Klassenanzeige
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Klasse:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(className)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 4)

                        // Vorname
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vorname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Vorname", text: $firstName)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                                .disableAutocorrection(true)
                        }
                        .padding(.vertical, 4)

                        // Nachname
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nachname:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Nachname", text: $lastName)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                                .disableAutocorrection(true)
                        }
                        .padding(.vertical, 4)

                        // Notizen
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notizen (optional):")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextEditor(text: $notes)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                    }

                    // Fehlermeldung (falls vorhanden)
                    if showValidationError {
                        Section {
                            Text(validationErrorMessage)
                                .foregroundColor(.red)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 450) // Begrenze die Höhe des Forms

                // Buttons unten
                VStack(spacing: 12) {
                    // Speichern-Button
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isSaving)

                    // Speichern und weiteren Schüler hinzufügen
                    Button(action: {
                        saveStudentAndAddAnother()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Speichern und weiteren Schüler hinzufügen")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isSaving)

                    // Abbrechen-Button
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Abbrechen")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationBarTitle("Schüler hinzufügen", displayMode: .inline)
        }
    }


    // 5. Schließlich aktualisieren wir die AddStudentView, um die Überprüfung auf doppelte Namen zu verbessern:

    private func saveStudent() {
        guard validateInputs() else { return }

        isSaving = true

        // Prüfen ob Klassenlimit erreicht ist
        let currentStudentCount = viewModel.getStudentCountForClass(classId: classId)
        if currentStudentCount >= 40 {
            showError("Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
            isSaving = false
            return
        }

        // Prüfen auf doppelte Namen
        if !viewModel.isStudentNameUnique(firstName: firstName, lastName: lastName, classId: classId) {
            showError("Ein Schüler mit dem Namen '\(firstName) \(lastName)' existiert bereits in dieser Klasse.")
            isSaving = false
            return
        }

        print("DEBUG: Speichere Schüler: \(firstName) \(lastName) in Klasse \(className)")

        let newStudent = Student(
            firstName: firstName,
            lastName: lastName,
            classId: classId,
            notes: notes.isEmpty ? nil : notes
        )

        // Leichte Verzögerung, um sicherzustellen, dass die UI aktualisiert wird
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.viewModel.addStudent(newStudent) {
                self.isSaving = false
                self.isPresented = false
            } else {
                // Falls ein anderer Fehler aufgetreten ist
                if let errorMsg = self.viewModel.errorMessage {
                    self.showError(errorMsg)
                } else {
                    self.showError("Fehler beim Speichern des Schülers.")
                }
                self.isSaving = false
            }
        }
    }

    private func saveStudentAndAddAnother() {
        guard validateInputs() else { return }

        isSaving = true

        // Prüfen ob Klassenlimit erreicht ist
        let currentStudentCount = viewModel.getStudentCountForClass(classId: classId)
        if currentStudentCount >= 40 {
            showError("Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
            isSaving = false
            return
        }

        print("DEBUG: Speichere Schüler und füge weiteren hinzu: \(firstName) \(lastName) in Klasse \(className)")

        let newStudent = Student(
            firstName: firstName,
            lastName: lastName,
            classId: classId,
            notes: notes.isEmpty ? nil : notes
        )

        // Leichte Verzögerung, um sicherzustellen, dass die UI aktualisiert wird
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.viewModel.addStudent(newStudent) {
                // Felder zurücksetzen für den nächsten Schüler
                self.firstName = ""
                self.lastName = ""
                self.notes = ""
                self.showValidationError = false
            }
            self.isSaving = false
        }
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
}
