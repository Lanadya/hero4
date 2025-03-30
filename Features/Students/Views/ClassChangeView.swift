import SwiftUI

struct ClassChangeView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool

    // State variables
    @State private var selectedClassId: UUID?
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showConfirmation = false
    @State private var isSuccess = false
    @State private var showScrollHelp = false
    @State private var preventRepeatedTrigger = false

    // Helper computed properties
    private var sourceClassName: String {
        viewModel.dataStore.getClass(id: student.classId)?.name ?? "Unbekannt"
    }

    private var targetClassName: String? {
        guard let classId = selectedClassId else { return nil }
        return viewModel.dataStore.getClass(id: classId)?.name
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Schüler in andere Klasse verschieben")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Button(action: {
                            showScrollHelp = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }

                    // Student info
                    Text(student.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Current class display
                    HStack {
                        Text("Aktuelle Klasse:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(sourceClassName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }

                    // Selected target class (if any)
                    if let targetName = targetClassName {
                        HStack {
                            Text("Zielklasse:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(targetName)
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                // Error message (if any)
                if showError, let message = errorMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // Success message (if needed)
                if isSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        Text("Schüler erfolgreich verschoben!")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Class selection
                if viewModel.classes.filter({ $0.id != student.classId }).isEmpty {
                    Text("Es sind keine anderen Klassen verfügbar.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    // Instructions
                    Text("Bitte wählen Sie die Zielklasse:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Specialized class list for this use case
                    ClassChangeListView(
                        classes: viewModel.classes.filter { $0.id != student.classId },
                        selectedClassId: $selectedClassId,
                        onClassSelected: { classId in
                            // Reset errors when a new class is selected
                            selectedClassId = classId
                            errorMessage = nil
                            showError = false
                        }
                    )
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)

                // Action buttons
                VStack(spacing: 12) {
                    // Move button
                    Button(action: {
                        if !preventRepeatedTrigger {
                            preventRepeatedTrigger = true
                            validateAndShowConfirmation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                preventRepeatedTrigger = false
                            }
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
                        } else if let targetName = targetClassName {
                            Text("Nach \(targetName) verschieben")
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
                    .disabled(selectedClassId == nil || isProcessing || isSuccess)
                    .padding(.horizontal)

                    // Cancel/Close button
                    Button(isSuccess ? "Schließen" : "Abbrechen") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Schließen") {
                isPresented = false
            })
            .alert("Hilfe zur Klassenauswahl", isPresented: $showScrollHelp) {
                Button("Schließen", role: .cancel) { }
            } message: {
                Text("Falls nicht alle Klassen sichtbar sind, können Sie innerhalb der Klassenliste nach oben wischen, um weitere Klassen anzuzeigen.\n\nTippen Sie auf eine Klasse, um sie auszuwählen.\n\nNach der Auswahl wird die gewählte Klasse unter 'Zielklasse' angezeigt.")
            }
            .alert("Klassenwechsel bestätigen", isPresented: $showConfirmation) {
                Button("Abbrechen", role: .cancel) {
                    print("DEBUG: Confirmation canceled.")
                }
                Button("Bestätigen") {
                    print("DEBUG: Confirmation accepted. Executing class change.")
                    executeClassChange()
                }
            } message: {
                Text("Die bisherigen Noten des Schülers werden archiviert und sind in der neuen Klasse nicht mehr sichtbar. Sie können im Archiv-Tab eingesehen werden.\n\nSchüler: \(student.fullName)\nVon: \(sourceClassName)\nNach: \(targetClassName ?? "")")
            }
            .onChange(of: viewModel.showError) { _, newValue in
                if newValue {
                    errorMessage = viewModel.errorMessage
                    showError = true
                    viewModel.showError = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Functions for student movement

    // Validation and showing the confirmation query
    private func validateAndShowConfirmation() {
        print("DEBUG: validateAndShowConfirmation called. selectedClassId: \(selectedClassId?.uuidString ?? "nil")")

        guard let targetId = selectedClassId else {
            errorMessage = "Bitte wählen Sie eine Zielklasse aus."
            showError = true
            return
        }

        // Validate class size
        let studentsInTargetClass = viewModel.getStudentCountForClass(classId: targetId)
        if studentsInTargetClass >= 40 {
            errorMessage = "Die Zielklasse '\(targetClassName ?? "")' hat bereits 40 Schüler."
            showError = true
            return
        }

        // Validate name uniqueness
        if !viewModel.isStudentNameUnique(
            firstName: student.firstName,
            lastName: student.lastName,
            classId: targetId,
            exceptStudentId: student.id
        ) {
            errorMessage = "Ein Schüler mit dem Namen '\(student.fullName)' existiert bereits in der Zielklasse."
            showError = true
            return
        }

        // Set the state to show confirmation
        print("DEBUG: Validation passed, showing confirmation dialog")
        showConfirmation = true
    }

    // Execute the class change after confirmation
    private func executeClassChange() {
        guard let targetId = selectedClassId else { return }

        isProcessing = true
        print("DEBUG: Executing class change. Student ID: \(student.id), From Class: \(student.classId), To Class: \(targetId)")

        // Perform the actual class change
        viewModel.moveStudentToClassWithStatus(studentId: student.id, newClassId: targetId)

        // Force data reload
        viewModel.loadStudentsForSelectedClass()

        // Update UI with success state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("DEBUG: Class change completed. Setting success state.")
            self.isProcessing = false
            self.isSuccess = true

            // Delay to show success message before closing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("DEBUG: Closing class change view.")
                self.isPresented = false
            }
        }
    }
}

// Specialized class list view specifically for class changes
struct ClassChangeListView: View {
    let classes: [Class]
    @Binding var selectedClassId: UUID?
    let onClassSelected: (UUID) -> Void

    // Group classes by weekday
    private var classesByWeekday: [(weekday: String, classes: [Class])] {
        let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]

        var result: [(weekday: String, classes: [Class])] = []

        for (index, weekday) in weekdays.enumerated() {
            let column = index + 1
            let classesForDay = classes.filter { $0.column == column }.sorted { $0.row < $1.row }

            if !classesForDay.isEmpty {
                result.append((weekday: weekday, classes: classesForDay))
            }
        }

        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(classesByWeekday, id: \.weekday) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Weekday header
                        Text(group.weekday)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)

                        // Classes for this day
                        ForEach(group.classes) { classObj in
                            Button(action: {
                                onClassSelected(classObj.id)
                            }) {
                                HStack {
                                    // Class name and note
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(classObj.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        if let note = classObj.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()

                                    // Selection indicator
                                    if selectedClassId == classObj.id {
                                        Text("Ausgewählt")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedClassId == classObj.id ?
                                              Color.blue.opacity(0.1) :
                                              Color.white)
                                        .shadow(
                                            color: Color.black.opacity(selectedClassId == classObj.id ? 0.1 : 0.05),
                                            radius: 2,
                                            x: 0,
                                            y: 1
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

//import SwiftUI
//
//struct ClassChangeView: View {
//    let student: Student
//    @ObservedObject var viewModel: StudentsViewModel
//    @Binding var isPresented: Bool
//
//    // State-Variablen
//    @State private var selectedClassId: UUID?
//    @State private var isProcessing = false
//    @State private var errorMessage: String? = nil
//    @State private var showError = false
//    @State private var showConfirmation = false
//    @State private var isSuccess = false
//    @State private var showScrollHelp = false
//
//    // Hilfsvariablen für die Benutzeroberfläche
//    private var sourceClassName: String {
//        viewModel.dataStore.getClass(id: student.classId)?.name ?? "Unbekannt"
//    }
//
//    private var targetClassName: String? {
//        guard let classId = selectedClassId else { return nil }
//        return viewModel.dataStore.getClass(id: classId)?.name
//    }
//
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 0) {
//                // Header-Bereich
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Text("Schüler in andere Klasse verschieben")
//                            .font(.headline)
//                            .padding(.bottom, 4)
//
//                        Button(action: {
//                            showScrollHelp = true
//                        }) {
//                            Image(systemName: "info.circle")
//                                .font(.footnote)
//                                .foregroundColor(.blue)
//                        }
//                        .buttonStyle(BorderlessButtonStyle())
//                    }
//
//                    // Schülerinfo
//                    Text(student.fullName)
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//
//                    // Aktuelle Klassenanzeige
//                    HStack {
//                        Text("Aktuelle Klasse:")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//
//                        Text(sourceClassName)
//                            .font(.subheadline)
//                            .foregroundColor(.primary)
//                            .fontWeight(.medium)
//                    }
//
//                    // Ausgewählte Zielklasse (falls vorhanden)
//                    if let targetName = targetClassName {
//                        HStack {
//                            Text("Zielklasse:")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//
//                            Text(targetName)
//                                .font(.subheadline)
//                                .foregroundColor(.green)
//                                .fontWeight(.medium)
//                        }
//                        .padding(.top, 4)
//                    }
//                }
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//
//                // Fehlermeldung (falls vorhanden)
//                if showError, let message = errorMessage {
//                    Text(message)
//                        .font(.subheadline)
//                        .foregroundColor(.red)
//                        .padding()
//                        .background(Color.red.opacity(0.1))
//                        .cornerRadius(8)
//                        .padding(.horizontal)
//                }
//
//                // Erfolgsmeldung (falls erforderlich)
//                if isSuccess {
//                    HStack {
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//
//                        Text("Schüler erfolgreich verschoben!")
//                            .foregroundColor(.green)
//                            .fontWeight(.medium)
//                    }
//                    .padding()
//                    .background(Color.green.opacity(0.1))
//                    .cornerRadius(8)
//                    .padding(.horizontal)
//                }
//
//                // Klassenauswahl
//                if viewModel.classes.filter({ $0.id != student.classId }).isEmpty {
//                    Text("Es sind keine anderen Klassen verfügbar.")
//                        .foregroundColor(.gray)
//                        .padding()
//                } else {
//                    // Anleitung
//                    Text("Bitte wählen Sie die Zielklasse:")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .padding(.horizontal)
//                        .padding(.top, 4)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//
//                    // Spezielle Klassenliste für diesen Anwendungsfall
//                    ClassChangeListView(
//                        classes: viewModel.classes.filter { $0.id != student.classId },
//                        selectedClassId: $selectedClassId,
//                        onClassSelected: { classId in
//                            // Wenn eine neue Klasse gewählt wird, Fehler zurücksetzen
//                            selectedClassId = classId
//                            errorMessage = nil
//                            showError = false
//                        }
//                    )
//                    .padding(.top, 4)
//                }
//
//                Spacer(minLength: 0)
//
//                // Aktionsbuttons
//                VStack(spacing: 12) {
//                    // Verschieben-Button
//                    Button(action: {
//                        moveStudent()
//                    }) {
//                        if isProcessing {
//                            HStack {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle())
//                                    .padding(.trailing, 8)
//                                Text("Verschiebe...")
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        } else if let targetName = targetClassName {
//                            Text("Nach \(targetName) verschieben")
//                                .frame(maxWidth: .infinity, alignment: .center)
//                        } else {
//                            Text("Verschieben")
//                                .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                    }
//                    .foregroundColor(.white)
//                    .padding(.vertical, 12)
//                    .background(selectedClassId != nil ? Color.blue : Color.gray)
//                    .cornerRadius(10)
//                    .disabled(selectedClassId == nil || isProcessing || isSuccess)
//                    .padding(.horizontal)
//
//                    // Abbrechen/Schließen-Button
//                    Button(isSuccess ? "Schließen" : "Abbrechen") {
//                        isPresented = false
//                    }
//                    .frame(maxWidth: .infinity, alignment: .center)
//                    .foregroundColor(.red)
//                    .padding(.vertical, 12)
//                    .background(Color.red.opacity(0.1))
//                    .cornerRadius(10)
//                    .padding(.horizontal)
//                }
//                .padding(.vertical)
//                .background(Color.white)
//                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
//
//                .alert(isPresented: $showConfirmation) {
//                    Alert(
//                        title: Text("Klassenwechsel bestätigen"),
//                        message: Text("Die bisherigen Noten des Schülers werden archiviert und sind in der neuen Klasse nicht mehr sichtbar. Sie können im Archiv-Tab eingesehen werden.\n\nSchüler: \(student.fullName)\nVon: \(sourceClassName)\nNach: \(targetClassName ?? "")"),
//                        primaryButton: .default(Text("Bestätigen")) {
//                            confirmMoveStudent()
//                        },
//                        secondaryButton: .cancel()
//                    )
//                }
//            }
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationBarItems(trailing: Button("Schließen") {
//                isPresented = false
//            })
//
//            .alert(isPresented: $showScrollHelp) {
//                Alert(
//                    title: Text("Hilfe zur Klassenauswahl"),
//                    message: Text("Falls nicht alle Klassen sichtbar sind, können Sie innerhalb der Klassenliste nach oben wischen, um weitere Klassen anzuzeigen.\n\nTippen Sie auf eine Klasse, um sie auszuwählen.\n\nNach der Auswahl wird die gewählte Klasse unter 'Zielklasse' angezeigt."),
//                    dismissButton: .default(Text("Schließen"))
//                )
//            }
//            .onChange(of: viewModel.showError) { _, newValue in
//                if newValue {
//                    errorMessage = viewModel.errorMessage
//                    showError = true
//                    viewModel.showError = false
//                }
//            }
//        }
//        .presentationDetents([.large])
//        .presentationDragIndicator(.visible)
//    }
//
//    // Validierung und Anzeige der Bestätigungsabfrage
//    private func moveStudent() {
//        print("DEBUG: moveStudent called. selectedClassId: \(selectedClassId?.uuidString ?? "nil")")
//
//        guard let targetId = selectedClassId else {
//            errorMessage = "Bitte wählen Sie eine Zielklasse aus."
//            showError = true
//            return
//        }
//
//        // Validiere Klassengröße
//        let studentsInTargetClass = viewModel.getStudentCountForClass(classId: targetId)
//        if studentsInTargetClass >= 40 {
//            errorMessage = "Die Zielklasse '\(targetClassName ?? "")' hat bereits 40 Schüler."
//            showError = true
//            return
//        }
//
//        // Validiere Namensuniqueness
//        if !viewModel.isStudentNameUnique(
//            firstName: student.firstName,
//            lastName: student.lastName,
//            classId: targetId,
//            exceptStudentId: student.id
//        ) {
//            errorMessage = "Ein Schüler mit dem Namen '\(student.fullName)' existiert bereits in der Zielklasse."
//            showError = true
//            return
//        }
//        // Set this flag to trigger the confirmation dialog
//           print("DEBUG: Showing confirmation dialog")
//        // Zeige Bestätigungsdialog
//        showConfirmation = true
//    }
//
//    // Ausführung nach Bestätigung - mit verbesserter Implementierung
//    private func confirmMoveStudent() {
//        print("DEBUG: confirmMoveStudent called. selectedClassId: \(selectedClassId?.uuidString ?? "nil")")
//
//        guard let targetId = selectedClassId else { return }
//
//        isProcessing = true
//        print("Verschiebe Schüler \(student.id) von \(student.classId) nach \(targetId)")
//
//        // Führe die tatsächliche Verschiebung aus
//        viewModel.moveStudentToClass(studentId: student.id, newClassId: targetId)
//
//        // Zwinge ein Neuladen der Daten
//        viewModel.loadStudentsForSelectedClass()
//
//        // Aktualisiere UI und schließe Fenster nach kurzer Verzögerung
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
//            print("DEBUG: Class change completed. Setting success state.")
//            isProcessing = false
//            isSuccess = true
//
//            // Noch etwas Verzögerung, um die Erfolgsmeldung anzuzeigen
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                print("DEBUG: Closing class change view.")
//                isPresented = false
//            }
//        }
//    }
//}
//
//// Spezialisierte Klassenliste speziell für den Klassenwechsel
//struct ClassChangeListView: View {
//    let classes: [Class]
//    @Binding var selectedClassId: UUID?
//    let onClassSelected: (UUID) -> Void
//
//    // Die Klassen nach Wochentagen gruppieren
//    private var classesByWeekday: [(weekday: String, classes: [Class])] {
//        let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
//
//        var result: [(weekday: String, classes: [Class])] = []
//
//        for (index, weekday) in weekdays.enumerated() {
//            let column = index + 1
//            let classesForDay = classes.filter { $0.column == column }.sorted { $0.row < $1.row }
//
//            if !classesForDay.isEmpty {
//                result.append((weekday: weekday, classes: classesForDay))
//            }
//        }
//
//        return result
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 16) {
//                ForEach(classesByWeekday, id: \.weekday) { group in
//                    VStack(alignment: .leading, spacing: 8) {
//                        // Wochentag-Header
//                        Text(group.weekday)
//                            .font(.headline)
//                            .foregroundColor(.secondary)
//                            .padding(.leading, 16)
//
//                        // Klassen für diesen Tag
//                        ForEach(group.classes) { classObj in
//                            Button(action: {
//                                onClassSelected(classObj.id)
//                            }) {
//                                HStack {
//                                    // Klassenname und Notiz
//                                    VStack(alignment: .leading, spacing: 2) {
//                                        Text(classObj.name)
//                                            .font(.system(size: 16, weight: .medium))
//                                            .foregroundColor(.primary)
//
//                                        if let note = classObj.note, !note.isEmpty {
//                                            Text(note)
//                                                .font(.caption)
//                                                .foregroundColor(.gray)
//                                        }
//                                    }
//
//                                    Spacer()
//
//                                    // Auswahlindikator
//                                    if selectedClassId == classObj.id {
//                                        Text("Ausgewählt")
//                                            .font(.caption)
//                                            .foregroundColor(.white)
//                                            .padding(.horizontal, 8)
//                                            .padding(.vertical, 3)
//                                            .background(Color.blue)
//                                            .cornerRadius(12)
//                                    }
//                                }
//                                .padding(.vertical, 10)
//                                .padding(.horizontal, 16)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 8)
//                                        .fill(selectedClassId == classObj.id ?
//                                              Color.blue.opacity(0.1) :
//                                              Color.white)
//                                        .shadow(
//                                            color: Color.black.opacity(selectedClassId == classObj.id ? 0.1 : 0.05),
//                                            radius: 2,
//                                            x: 0,
//                                            y: 1
//                                        )
//                                )
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                            .padding(.horizontal, 16)
//                        }
//                    }
//                    .padding(.bottom, 8)
//                }
//            }
//            .padding(.vertical, 8)
//        }
//        .background(Color(.systemGroupedBackground))
//    }
//}
