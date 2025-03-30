import SwiftUI

struct EditClassView: View {
    let `class`: Class
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var isPresented: Bool

    @State private var className: String
    @State private var classNote: String
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var navigateToStudentsList: Bool = false

    init(class: Class, viewModel: TimetableViewModel, isPresented: Binding<Bool>) {
        self.`class` = `class`
        self.viewModel = viewModel
        self._isPresented = isPresented

        _className = State(initialValue: `class`.name)
        _classNote = State(initialValue: `class`.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Klasse bearbeiten")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Position:")
                            .font(.headline)

                        HStack {
                            Text("Zeile \(`class`.row), Spalte \(`class`.column)")
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

                        TextField("Klassenname", text: $className)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: className) { oldValue, newValue in
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

                        TextField("Notiz", text: $classNote)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: classNote) { oldValue, newValue in
                                if newValue.count > 10 {
                                    classNote = String(newValue.prefix(10))
                                }
                            }
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Erstellt am:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formatDate(`class`.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zuletzt bearbeitet:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formatDate(`class`.modifiedAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
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
                        saveClass()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Speichern")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.blue)

                    Button(action: {
                        navigateToStudentsList = true
                    }) {
                        HStack {
                            Image(systemName: "person.3.fill")
                            Text("Zur Schülerliste")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.blue)
                }

                Section {
                    Button(action: {
                        archiveClass()
                    }) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Archivieren")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.orange)

                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Löschen")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.red)
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
                    .foregroundColor(.gray)
                }
            }
            .navigationBarTitle("Klasse: \(`class`.name)", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Text("Schließen")
            })
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Klasse löschen"),
                    message: Text("Möchten Sie die Klasse \(`class`.name) wirklich löschen? Dies kann nicht rückgängig gemacht werden."),
                    primaryButton: .destructive(Text("Löschen")) {
                        deleteClass()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
            .navigationDestination(isPresented: $navigateToStudentsList) {
                StudentsListView()
            }
        }
    }

    private func saveClass() {
        guard validateInputs() else { return }

        var updatedClass = `class`
        updatedClass.name = className
        updatedClass.note = classNote.isEmpty ? nil : classNote
        updatedClass.modifiedAt = Date()

        viewModel.saveClass(updatedClass)
        isPresented = false
    }

    private func archiveClass() {
        viewModel.archiveClass(`class`)
        isPresented = false
    }

    private func deleteClass() {
        viewModel.deleteClass(id: `class`.id)
        isPresented = false
    }

    private func validateInputs() -> Bool {
        // Klassenname darf nicht leer sein
        if className.isEmpty {
            showError("Bitte geben Sie einen Klassennamen ein.")
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
}

