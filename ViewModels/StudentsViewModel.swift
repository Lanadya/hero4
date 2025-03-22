import Foundation
import Combine

class StudentsViewModel: ObservableObject {
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var students: [Student] = []
    @Published var allStudents: [Student] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var globalSearchText: String = ""
    @Published var searchResults: [SearchResult] = []

    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    struct SearchResult: Identifiable {
        var id: UUID { student.id }
        var student: Student
        var className: String
    }

    init(initialClassId: UUID? = nil) {
        // Wenn eine initiale Klassen-ID übergeben wurde, diese verwenden
        if let classId = initialClassId {
            selectedClassId = classId
            print("DEBUG ViewModel: Initialisiere mit Klassen-ID: \(classId)")
        }
        // Sonst prüfen, ob eine zuletzt erstellte Klasse gespeichert wurde
        else if let savedIdString = UserDefaults.standard.string(forKey: "lastCreatedClassId"),
                let savedId = UUID(uuidString: savedIdString) {
            selectedClassId = savedId
            // ID nach Nutzung löschen
            UserDefaults.standard.removeObject(forKey: "lastCreatedClassId")
            print("DEBUG ViewModel: Initialisiere mit gespeicherter Klassen-ID: \(savedId)")
        }

        // Beobachte Änderungen bei den Schülern im DataStore
        dataStore.$students
            .receive(on: RunLoop.main)
            .sink { [weak self] students in
                self?.allStudents = students.filter { !$0.isArchived }
                self?.loadStudentsForSelectedClass()
                self?.performGlobalSearch()
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Klassen im DataStore
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSelectedClass()
                self?.performGlobalSearch()
            }
            .store(in: &cancellables)

        // Initialen Klassenstatus laden
        updateSelectedClass()
    }

    // MARK: - Klassen-Operationen

    var classes: [Class] {
        return dataStore.classes.filter { !$0.isArchived }
    }

    // Klassen nach Wochentagen gruppiert
    var classesByWeekday: [(weekday: String, classes: [Class])] {
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

    func selectClass(id: UUID?) {
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()
    }

    private func updateSelectedClass() {
        if let classId = selectedClassId {
            selectedClass = dataStore.getClass(id: classId)

            // Wenn die ausgewählte Klasse nicht mehr existiert, setze auf nil
            if selectedClass == nil {
                selectedClassId = nil
            }
        } else {
            selectedClass = nil
        }
    }

    // MARK: - Schüler-Operationen

    func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            return
        }

        isLoading = true

        // Hole alle Schüler für die ausgewählte Klasse
        var allStudentsForClass = dataStore.getStudentsForClass(classId: classId)

        // Filtern nach Suchtext, wenn vorhanden
        if !searchText.isEmpty {
            let searchTextLower = searchText.lowercased()
            allStudentsForClass = allStudentsForClass.filter { student in
                student.firstName.lowercased().contains(searchTextLower) ||
                student.lastName.lowercased().contains(searchTextLower)
            }
        }

        // Nach Nachnamen und dann Vornamen sortieren
        students = allStudentsForClass.sorted {
            let lastNameComparison = $0.lastName.lowercased() < $1.lastName.lowercased()
            if $0.lastName.lowercased() == $1.lastName.lowercased() {
                return $0.firstName.lowercased() < $1.firstName.lowercased()
            }
            return lastNameComparison
        }

        isLoading = false
    }

    func getStudentCountForClass(classId: UUID) -> Int {
        return dataStore.getStudentsForClass(classId: classId).count
    }

    // In StudentsViewModel.swift, ersetze die bestehende addStudent-Methode mit dieser:

//    func addStudent(_ student: Student) {
//        do {
//            try student.validate()
//
//            // Prüfen, ob das Limit von 40 Schülern pro Klasse erreicht ist
//            let currentCount = getStudentCountForClass(classId: student.classId)
//            if currentCount >= 40 {
//                showError(message: "Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
//                return
//            }
//
//            // Prüfen auf doppelte Namen
//            if !dataStore.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId) {
//                showError(message: "Ein Schüler mit dem Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
//                return
//            }
//
//            dataStore.addStudent(student)
//            loadStudentsForSelectedClass()
//        } catch Student.ValidationError.noName {
//            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
//        } catch {
//            showError(message: "Fehler beim Speichern des Schülers: \(error.localizedDescription)")
//        }
//    }
    // Im StudentsViewModel:
    func addStudent(_ student: Student) -> Bool {
        do {
            try student.validate()

            // Prüfen, ob das Limit von 40 Schülern pro Klasse erreicht ist
            let currentCount = getStudentCountForClass(classId: student.classId)
            if currentCount >= 40 {
                showError(message: "Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
                return false
            }

            // Prüfen auf doppelte Namen
            if !dataStore.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId) {
                showError(message: "Ein Schüler mit dem Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return false
            }

            dataStore.addStudent(student)
            loadStudentsForSelectedClass()
            return true
        } catch Student.ValidationError.noName {
            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
            return false
        } catch {
            showError(message: "Fehler beim Speichern des Schülers: \(error.localizedDescription)")
            return false
        }
    }

    func updateStudent(_ student: Student) {
        do {
            try student.validate()

            // Prüfen auf doppelte Namen (aber den aktuellen Schüler selbst ausschließen)
            if !dataStore.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId, exceptStudentId: student.id) {
                showError(message: "Ein Schüler mit dem Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return
            }

            dataStore.updateStudent(student)
            loadStudentsForSelectedClass()
        } catch Student.ValidationError.noName {
            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
        } catch {
            showError(message: "Fehler beim Aktualisieren des Schülers: \(error.localizedDescription)")
        }
    }

    func deleteStudent(id: UUID) {
        dataStore.deleteStudent(id: id)
        loadStudentsForSelectedClass()
    }

    func archiveStudent(_ student: Student) {
        dataStore.archiveStudent(student)
        loadStudentsForSelectedClass()
    }

    // Verschieben eines Schülers in eine andere Klasse
    func moveStudentToClass(studentId: UUID, newClassId: UUID) {
        guard let student = dataStore.getStudent(id: studentId) else {
            showError(message: "Schüler nicht gefunden.")
            return
        }

        // Prüfen, ob die Zielklasse das Limit von 40 Schülern erreicht hat
        let studentsInTargetClass = getStudentCountForClass(classId: newClassId)
        if studentsInTargetClass >= 40 {
            showError(message: "Die Zielklasse hat bereits 40 Schüler. Der Schüler kann nicht hinzugefügt werden.")
            return
        }

        // Aktualisiere den Schüler mit der neuen Klassen-ID
        var updatedStudent = student
        updatedStudent.classId = newClassId

        // Speichere den aktualisierten Schüler
        dataStore.updateStudent(updatedStudent)

        // Aktualisiere auch die Sitzposition, falls vorhanden
        if let position = dataStore.getSeatingPosition(studentId: studentId, classId: student.classId) {
            // Lösche alte Sitzposition
            dataStore.deleteSeatingPosition(id: position.id)

            // Erstelle neue Sitzposition mit Standard-Werten
            let newPosition = SeatingPosition(
                studentId: studentId,
                classId: newClassId,
                xPos: 0,  // Standard-Position in der neuen Klasse
                yPos: 0
            )
            dataStore.addSeatingPosition(newPosition)
        }

        // Aktualisiere die Schülerliste
        loadStudentsForSelectedClass()
    }

    // MARK: - Globale Suche

    func performGlobalSearch() {
        // Leere Suchergebnisse nur bei leerem Suchtext
        if globalSearchText.isEmpty {
            searchResults = []
            return
        }

        let searchTextLower = globalSearchText.lowercased()
        var results: [SearchResult] = []

        // Durchsuche alle nicht-archivierten Schüler
        for student in allStudents {
            if student.firstName.lowercased().contains(searchTextLower) ||
                student.lastName.lowercased().contains(searchTextLower) {

                // Klasse für den Schüler finden
                if let classObj = dataStore.getClass(id: student.classId) {
                    results.append(SearchResult(student: student, className: classObj.name))
                }
            }
        }

        // Sortiere die Ergebnisse nach Relevanz
        results.sort { (result1, result2) -> Bool in
            // Exakte Übereinstimmungen bevorzugen
            let r1FirstNameMatch = result1.student.firstName.lowercased() == searchTextLower
            let r1LastNameMatch = result1.student.lastName.lowercased() == searchTextLower
            let r2FirstNameMatch = result2.student.firstName.lowercased() == searchTextLower
            let r2LastNameMatch = result2.student.lastName.lowercased() == searchTextLower

            if (r1FirstNameMatch || r1LastNameMatch) && !(r2FirstNameMatch || r2LastNameMatch) {
                return true
            }
            if !(r1FirstNameMatch || r1LastNameMatch) && (r2FirstNameMatch || r2LastNameMatch) {
                return false
            }

            // Wenn beides Teilübereinstimmungen sind, sortiere alphabetisch
            return result1.student.sortableName < result2.student.sortableName
        }

        // KEINE Begrenzung der Anzahl - alle Ergebnisse anzeigen
        searchResults = results

        print("DEBUG: Suche nach '\(globalSearchText)' ergab \(searchResults.count) Ergebnisse.")
    }

    func updateGlobalSearchText(_ text: String) {
        globalSearchText = text
        performGlobalSearch()
    }

    func clearGlobalSearch() {
        globalSearchText = ""
        searchResults = []
    }

    // MARK: - Klassenbezogene Suche

    func updateSearchText(_ text: String) {
        searchText = text
        loadStudentsForSelectedClass()
    }

    func clearSearch() {
        searchText = ""
        loadStudentsForSelectedClass()
    }

    // MARK: - Fehlerbehandlung

    func showError(message: String) {
        print("FEHLER: \(message)")
        errorMessage = message
        showError = true
    }


    // 2. Nun aktualisieren wir die StudentsViewModel-Klasse mit der Validierungsmethode:

    // In StudentsViewModel.swift füge diese Methode hinzu:
    func isStudentNameUnique(firstName: String, lastName: String, classId: UUID, exceptStudentId: UUID? = nil) -> Bool {
        return dataStore.isStudentNameUnique(firstName: firstName, lastName: lastName, classId: classId, exceptStudentId: exceptStudentId)
    }
}
