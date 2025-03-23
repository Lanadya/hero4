
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

    // Umgebungsvariablen
    @Environment(\.presentationMode) var presentationMode

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
            VStack {
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
                                .frame(height: 80)
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
                }

                // Buttons am unteren Rand
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
                        // Archivieren-Button
                        Button(action: {
                            showingArchiveConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "archivebox.fill")
                                Text("Archivieren")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)

                        // Löschen-Button
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Löschen")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)
                    }

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
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Schüler bearbeiten", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text("Abbrechen")
                        .foregroundColor(.red)
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
        .presentationDragIndicator(.visible) // Zeigt einen Drag-Indikator an
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

    private func validateInputs() -> Bool {
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
    @State private var showArchiveAlert = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

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

                if showError, let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if viewModel.classes.count > 1 {
                    Section {
                        Button(action: {
                            if selectedClassId != nil {
                                // Prüfen, ob die Zielklasse voll ist
                                let studentsInTargetClass = viewModel.getStudentCountForClass(classId: selectedClassId!)
                                if studentsInTargetClass >= 40 {
                                    errorMessage = "Die Zielklasse hat bereits 40 Schüler."
                                    showError = true
                                    return
                                }

                                // Prüfen, ob der Schülername in der Zielklasse bereits existiert
                                if !viewModel.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: selectedClassId!) {
                                    errorMessage = "Ein Schüler mit diesem Namen existiert bereits in der Zielklasse."
                                    showError = true
                                    return
                                }

                                showArchiveAlert = true
                            } else {
                                errorMessage = "Bitte wählen Sie eine Klasse aus."
                                showError = true
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
                if let firstClass = viewModel.classes.first(where: { $0.id != student.classId }) {
                    selectedClassId = firstClass.id
                }
            }
            .alert(isPresented: $showArchiveAlert) {
                Alert(
                    title: Text("Klassenwechsel bestätigen"),
                    message: Text("Die bisherigen Noten des Schülers werden archiviert und sind in der neuen Klasse nicht mehr sichtbar. Sie können im Archiv-Tab eingesehen werden."),
                    primaryButton: .default(Text("Bestätigen")) {
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.moveStudentToClass(studentId: student.id, newClassId: selectedClassId!)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isProcessing = false
                                isPresented = false
                            }
                        }
                    },
                    secondaryButton: .cancel(Text("Abbrechen")) {
                        showArchiveAlert = false
                    }
                )
            }
            .onChange(of: viewModel.showError) { newValue in
                if newValue {
                    errorMessage = viewModel.errorMessage
                    showError = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
