import SwiftUI

struct EditStudentView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool

    @State private var firstName: String
    @State private var lastName: String
    @State private var notes: String
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""
    @State private var showingDeleteConfirmation = false
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
            Form {
                Section(header: Text("Schüler bearbeiten")) {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Erfasst am:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formatDate(student.entryDate))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                // Klassen-Sektion
                Section(header: Text("Klasse")) {
                    if let classObj = viewModel.dataStore.getClass(id: student.classId) {
                        HStack {
                            Text("Aktuelle Klasse:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(classObj.name)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.leading, 8)

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        // Button zum Wechseln der Klasse
                        if viewModel.classes.count > 1 {
                            Button(action: {
                                showClassChangeModal = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                    Text("In andere Klasse verschieben")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                            }
                            .foregroundColor(.blue)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.top, 4)
                        }
                    } else {
                        Text("Klasse nicht gefunden")
                            .foregroundColor(.red)
                    }
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
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 6)
                    }
                    .disabled(isSaving)
                }

                Section {
                    Button(action: {
                        archiveStudent()
                    }) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Archivieren")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(.orange)
                    .disabled(isSaving)

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
                    .foregroundColor(.gray)
                    .disabled(isSaving)
                }
            }
            .navigationBarTitle("Schüler: \(student.fullName)", displayMode: .inline)
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
        }
    }

    private func saveStudent() {
        guard validateInputs() else { return }

        isSaving = true

        var updatedStudent = student
        updatedStudent.firstName = firstName
        updatedStudent.lastName = lastName
        updatedStudent.notes = notes.isEmpty ? nil : notes

        // Leichte Verzögerung, um die Benutzererfahrung zu verbessern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.viewModel.updateStudent(updatedStudent)
            self.isSaving = false
            self.isPresented = false
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
}

struct ClassChangeView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool
    @State private var selectedClassId: UUID?
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schüler in andere Klasse verschieben")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(student.fullName)
                                .font(.headline)

                            if let currentClass = viewModel.dataStore.getClass(id: student.classId) {
                                Text("Aktuelle Klasse: \(currentClass.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    if viewModel.classes.count <= 1 {
                        Text("Es sind keine anderen Klassen verfügbar.")
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        Text("Wählen Sie die neue Klasse:")
                            .font(.headline)
                            .padding(.top, 8)

                        Picker("Neue Klasse", selection: $selectedClassId) {
                            Text("Bitte wählen").tag(nil as UUID?)
                            ForEach(viewModel.classes.filter { $0.id != student.classId }) { classObj in
                                Text(classObj.name)
                                    .tag(classObj.id as UUID?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical, 8)
                    }
                }

                if viewModel.classes.count > 1 {
                    Section {
                        Button(action: {
                            if let newClassId = selectedClassId {
                                isProcessing = true

                                // Verzögerung für bessere UX
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.moveStudentToClass(studentId: student.id, newClassId: newClassId)

                                    // Kurze Verzögerung vor dem Schließen
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isProcessing = false
                                        isPresented = false
                                    }
                                }
                            } else {
                                viewModel.showError(message: "Bitte wählen Sie eine Klasse aus.")
                            }
                        }) {
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 8)
                                    Text("Verschiebe...")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Verschieben")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(selectedClassId != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .disabled(selectedClassId == nil || isProcessing)
                    }
                }

                Section {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("Klasse wechseln")
            .navigationBarItems(trailing: Button("Schließen") {
                isPresented = false
            })
            .onAppear {
                // Wähle standardmäßig die erste verfügbare Klasse
                if let firstClass = viewModel.classes.first(where: { $0.id != student.classId }) {
                    selectedClassId = firstClass.id
                }
            }
        }
    }
}
