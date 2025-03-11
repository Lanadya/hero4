import SwiftUI

struct AddClassView: View {
    let row: Int
    let column: Int
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var isPresented: Bool

    @State private var className: String = ""
    @State private var classNote: String = ""
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var navigateToStudentsList: Bool = false
    @State private var savedClassId: UUID?

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
                            Image(systemName: "checkmark.circle.fill")
                            Text("Speichern und zurück")
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)

                    Button(action: {
                        saveClass(navigateToStudents: true)
                    }) {
                        HStack {
                            Image(systemName: "person.3.fill")
                            Text("Speichern und zur Schülerliste")
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
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
                }
            }
            .navigationBarTitle("Klasse hinzufügen", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Text("Schließen")
            })
            .background(
                NavigationLink(
                    destination: StudentsListView(),
                    isActive: $navigateToStudentsList
                ) { EmptyView() }
            )
        }
    }

    private func saveClass(navigateToStudents: Bool) {
        guard validateInputs() else { return }

        print("DEBUG: Speichere Klasse an Position: Reihe \(row), Spalte \(column)")

        let newClass = Class(
            name: className,
            note: classNote.isEmpty ? nil : classNote,
            row: row,
            column: column
        )

        viewModel.saveClass(newClass)

        // Speichere die ID der neuen Klasse für die Navigation
        if let id = viewModel.getClassAt(row: row, column: column)?.id {
            savedClassId = id

            // Aktualisiere die UI, damit die neue Klasse sichtbar ist
            viewModel.loadClasses()

            // Navigiere nach einer kurzen Verzögerung, damit die UI Zeit hat sich zu aktualisieren
            if navigateToStudents {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.navigateToStudentsList = true
                }
            } else {
                isPresented = false
            }
        } else {
            isPresented = false
        }
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
