import SwiftUI

struct AddClassView: View {
    let row: Int
    let column: Int
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var isPresented: Bool
    @Binding var selectedTab: Int

    @State private var className: String = ""
    @State private var classNote: String = ""
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var isSaving: Bool = false

    // Bestimme Wochentag anhand der Spalte
    private var weekday: String {
        let days = ["", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
        return column >= 1 && column <= 5 ? days[column] : "Unbekannt"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Neue Klasse anlegen")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Position:")
                            .font(.headline)

                        HStack {
                            Text("\(weekday), \(row). Stunde")
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Klassenname (max. 8 Zeichen):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("z.B. 8c, 10Bio, M11", text: $className)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: className) { newValue in
                                if newValue.count > 8 {
                                    className = String(newValue.prefix(8))
                                }
                            }
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notiz (max. 10 Zeichen, optional):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("z.B. Info, Vertretung", text: $classNote)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: classNote) { newValue in
                                if newValue.count > 10 {
                                    classNote = String(newValue.prefix(10))
                                }
                            }
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
                        saveClass(navigateToStudents: false)
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Speichern und zurück")
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .disabled(isSaving)

                    Button(action: {
                        saveClass(navigateToStudents: true)
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "person.3.fill")
                            }
                            Text("Speichern und zur Schülerliste")
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
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
            .navigationBarTitle("Klasse hinzufügen", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Text("Schließen")
            })
        }
        .disabled(isSaving)
    }

//    private func saveClass(navigateToStudents: Bool) {
//        guard validateInputs() else { return }
//
//        // Prevent double-saving
//        isSaving = true
//
//        print("DEBUG: Saving class at position: Row \(row), Column \(column)")
//
//        // Create a new class with a unique ID
//        let classId = UUID()
//        let newClass = Class(
//            id: classId,
//            name: className,
//            note: classNote.isEmpty ? nil : classNote,
//            row: row,
//            column: column
//        )
//
//        print("DEBUG: Creating new class with ID: \(classId)")
//
//        // Save the class
//        viewModel.saveClass(newClass)
//
//        // IMPORTANT: Store the class ID in our global AppState
//        AppState.shared.didCreateClass(classId)
//
//        // If we should navigate to the student list
//        if navigateToStudents {
//            // This will trigger the navigation in MainTabView
//            AppState.shared.shouldNavigateToStudentsList = true
//        }
//
//        // Force class reload
//        viewModel.loadClasses()
//
//        // Brief delay for UI
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            // Close modal
//            self.isPresented = false
//
//            // If needed, navigate to student list (TabBar handled by MainTabView)
//            if navigateToStudents {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    self.selectedTab = 1 // Switch to student list
//                }
//            }
//
//            self.isSaving = false
//        }
//    }

    private func saveClass(navigateToStudents: Bool) {
        // Prüfe, ob die Eingaben gültig sind
        guard validateInputs() else { return }

        isSaving = true

        // Erstelle eine neue Klasse mit einer eindeutigen ID
        let classId = UUID()
        let newClass = Class(
            id: classId,
            name: className,
            note: classNote.isEmpty ? nil : classNote,
            row: row,
            column: column
        )

        // Speichere die Klasse im ViewModel
        viewModel.saveClass(newClass)

        // Wenn der Nutzer zur Schülerliste navigieren will
        if navigateToStudents {
            // Speichere die ID der neuen Klasse in UserDefaults
            UserDefaults.standard.set(classId.uuidString, forKey: "selectedClassForStudentsList")

            // Wechsle zur Schülerliste (Tab 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.selectedTab = 1
            }
        }

        // Schließe das Modal
        self.isPresented = false
        self.isSaving = false
    }

    private func validateInputs() -> Bool {
        // Klassenname darf nicht leer sein
        if className.isEmpty {
            showError("Bitte geben Sie einen Klassennamen ein.")
            return false
        }

        // Prüfe, ob die Position gültig ist
        if row < 1 || row > 12 || column < 1 || column > 5 {
            showError("Die Position ist ungültig. Bitte wählen Sie eine Zelle im Stundenplan.")
            return false
        }

        return true
    }

    private func showError(_ message: String) {
        validationErrorMessage = message
        showValidationError = true
    }
}
