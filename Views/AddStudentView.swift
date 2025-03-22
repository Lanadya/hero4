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
            Form {
                Section(header: Text("Schüler hinzufügen")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Klasse:")
                            .font(.headline)

                        HStack {
                            Text(className)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vorname:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Vorname", text: $firstName)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .disableAutocorrection(true)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nachname:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Nachname", text: $lastName)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .disableAutocorrection(true)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen (optional):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(5)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                }

                if showValidationError {
                    Section {
                        Text(validationErrorMessage)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
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
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .disabled(isSaving)

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
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .disabled(isSaving)
                }

                Section {
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Abbrechen")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.red)
                    .disabled(isSaving)
                }
            }
            .navigationBarTitle("Schüler hinzufügen", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text("Abbrechen")
                        .foregroundColor(.red)
                }.disabled(isSaving),

                trailing: Button(action: {
                    saveStudent()
                }) {
                    Text("Speichern")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }.disabled(isSaving)
            )
        }
    }

    // 5. Schließlich aktualisieren wir die AddStudentView, um die Überprüfung auf doppelte Namen zu verbessern:


//    private func saveStudent() {
//        guard validateInputs() else { return }
//
//        isSaving = true
//
//        // Prüfen ob Klassenlimit erreicht ist
//        let currentStudentCount = viewModel.getStudentCountForClass(classId: classId)
//        if currentStudentCount >= 40 {
//            showError("Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
//            isSaving = false
//            return
//        }
//
//        // Validierung auf doppelte Namen erfolgt im ViewModel
//
//        print("DEBUG: Speichere Schüler: \(firstName) \(lastName) in Klasse \(className)")
//
//        let newStudent = Student(
//            firstName: firstName,
//            lastName: lastName,
//            classId: classId,
//            notes: notes.isEmpty ? nil : notes
//        )
//
//        // Leichte Verzögerung, um sicherzustellen, dass die UI aktualisiert wird
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            // Die eigentliche Validierung auf doppelte Namen erfolgt im ViewModel
//            // Wenn ein Fehler auftritt, wird die showError-Methode des ViewModels aufgerufen
//            self.viewModel.addStudent(newStudent)
//
//            // Wir prüfen, ob ein Fehler angezeigt wird
//            if self.viewModel.showError {
//                self.isSaving = false
//                // Die Fehlermeldung wird bereits im ViewModel angezeigt, also müssen wir hier nichts tun
//            } else {
//                self.isSaving = false
//                self.isPresented = false
//            }
//        }
//    }

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

        print("DEBUG: Speichere Schüler: \(firstName) \(lastName) in Klasse \(className)")

        let newStudent = Student(
            firstName: firstName,
            lastName: lastName,
            classId: classId,
            notes: notes.isEmpty ? nil : notes
        )

        // Leichte Verzögerung, um sicherzustellen, dass die UI aktualisiert wird
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Wenn der Schüler erfolgreich hinzugefügt wurde, schließe das Modal
            if self.viewModel.addStudent(newStudent) {
                self.isSaving = false
                self.isPresented = false
            } else {
                // Wenn nicht, bleibt das Modal offen und zeigt den Fehler
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
            viewModel.addStudent(newStudent)

            // Felder zurücksetzen für den nächsten Schüler
            firstName = ""
            lastName = ""
            notes = ""
            showValidationError = false
            isSaving = false
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
