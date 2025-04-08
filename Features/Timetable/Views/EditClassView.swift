import SwiftUI

struct EditClassView: View {
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var isPresented: Bool
    
    let classObj: Class
    
    @State private var className: String
    @State private var classNote: String
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var navigateToStudentsList = false
    
    init(viewModel: TimetableViewModel, classObj: Class, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.classObj = classObj
        self._isPresented = isPresented
        
        self._className = State(initialValue: classObj.name)
        self._classNote = State(initialValue: classObj.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Klasseninformationen")) {
                    TextField("Klassenname", text: $className)
                    
                    TextEditor(text: $classNote)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if classNote.isEmpty {
                                    HStack {
                                        Text("Notizen (optional)")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 4)
                                        Spacer()
                                    }
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                                }
                            }
                        )
                }
                
                Section(header: Text("Position im Stundenplan")) {
                    HStack {
                        Text("Reihe (Stunde): \(classObj.row)")
                        Spacer()
                        Text("Spalte (Tag): \(classObj.column)")
                    }
                    .padding(.vertical, 6)
                    
                    Text("Die Position kann nur beim Erstellen festgelegt werden.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Aktionen")) {
                    Button(action: {
                        navigateToStudentsList = true
                    }) {
                        HStack {
                            Image(systemName: "person.3")
                            Text("Schüler verwalten")
                        }
                    }
                    
                    Button(action: {
                        viewModel.archiveClass(classObj)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("Klasse archivieren")
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Klasse löschen")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if !classObj.createdAt.timeIntervalSinceNow.isZero {
                    Section(footer: Text("Erstellt: \(formatDate(classObj.createdAt))")) {
                        EmptyView()
                    }
                }
            }
            .navigationBarTitle("Klasse bearbeiten", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text("Abbrechen")
                },
                trailing: Button(action: {
                    saveClass()
                }) {
                    Text("Speichern")
                        .bold()
                }
            )
            .alert("Validierungsfehler", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
            .alert("Klasse löschen", isPresented: $showingDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    deleteClass()
                }
            } message: {
                Text("Möchten Sie die Klasse \(classObj.name) wirklich löschen? Dies kann nicht rückgängig gemacht werden.")
            }
            .navigationDestination(isPresented: $navigateToStudentsList) {
                StudentsListView()
            }
        }
    }

    private func saveClass() {
        guard validateInputs() else { return }

        var updatedClass = classObj
        updatedClass.name = className
        updatedClass.note = classNote.isEmpty ? nil : classNote
        updatedClass.modifiedAt = Date()

        viewModel.saveClass(updatedClass)
        isPresented = false
    }

    private func archiveClass() {
        viewModel.archiveClass(classObj)
        isPresented = false
    }

    private func deleteClass() {
        viewModel.deleteClass(id: classObj.id)
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

