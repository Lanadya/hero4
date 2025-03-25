import Foundation
import SwiftUI
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
        print("DEBUG: Selecting class ID: \(id?.uuidString ?? "none")")
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()

        // Force UI update
        objectWillChange.send()
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
        clearGlobalSearch()
    }

    func deleteStudent(id: UUID) {
        dataStore.deleteStudent(id: id) // Löscht den Schüler aus dem DataStore
        searchText = "" // Setzt die klassenbezogene Suche zurück
        loadStudentsForSelectedClass() // Lädt die aktualisierte Schülerliste
        clearGlobalSearch() // Setzt die globale Suche zurück, falls aktiv
        objectWillChange.send() // Informiert die UI über die Änderung
        print("DEBUG ViewModel: Schüler mit ID \(id) gelöscht und Liste aktualisiert")
    }

    func archiveStudent(_ student: Student) {
        dataStore.archiveStudent(student)
        loadStudentsForSelectedClass()
        clearGlobalSearch()
    }

    func moveStudentToClass(studentId: UUID, newClassId: UUID) {
        guard let student = dataStore.getStudent(id: studentId) else {
            showError(message: "Schüler nicht gefunden.")
            return
        }

        let oldClassId = student.classId

        // Prüfen, ob die Zielklasse voll ist (z. B. 40 Schüler)
        let studentsInTargetClass = getStudentCountForClass(classId: newClassId)
        if studentsInTargetClass >= 40 {
            showError(message: "Die Zielklasse hat bereits 40 Schüler.")
            return
        }

        // Prüfen, ob der Schülername in der Zielklasse bereits existiert
        if !dataStore.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: newClassId) {
            showError(message: "Ein Schüler mit diesem Namen existiert bereits in der Zielklasse.")
            return
        }

        // Noten aus der alten Klasse archivieren
        let ratingsToArchive = dataStore.getRatingsForStudent(studentId: studentId)
            .filter { $0.classId == oldClassId }
        for var rating in ratingsToArchive {
            rating.isArchived = true
            dataStore.updateRating(rating)
        }

        // Schüler in die neue Klasse verschieben
        var updatedStudent = student
        updatedStudent.classId = newClassId
        dataStore.updateStudent(updatedStudent)

        // Sitzposition anpassen (falls vorhanden)
        if let position = dataStore.getSeatingPosition(studentId: studentId, classId: oldClassId) {
            dataStore.deleteSeatingPosition(id: position.id)
        }
        let newPosition = SeatingPosition(
            studentId: studentId,
            classId: newClassId,
            xPos: 0,
            yPos: 0
        )
        dataStore.addSeatingPosition(newPosition)
    }

    func moveStudentsToClass(studentIds: [UUID], newClassId: UUID) {
        for studentId in studentIds {
            moveStudentToClass(studentId: studentId, newClassId: newClassId)
        }
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

    // In StudentsViewModel:
    func updateGlobalSearchText(_ text: String) {
        globalSearchText = text

        // Intelligente Suche basierend auf Länge
        if text.count == 0 {
            searchResults = []
        } else if text.count == 1 {
            // Bei einem Buchstaben: Nur exakte Treffer am Anfang des Namens
            let searchChar = text.lowercased()
            searchResults = allStudents.compactMap { student in
                if student.firstName.lowercased().hasPrefix(searchChar) ||
                   student.lastName.lowercased().hasPrefix(searchChar) {
                    if let classObj = dataStore.getClass(id: student.classId) {
                        return SearchResult(student: student, className: classObj.name)
                    }
                }
                return nil
            }
        } else if text.count == 2 {
            // Bei zwei Buchstaben: Treffer am Anfang + begrenzte Anzahl
            let searchText = text.lowercased()
            let matches = allStudents.compactMap { student in
                if student.firstName.lowercased().hasPrefix(searchText) ||
                   student.lastName.lowercased().hasPrefix(searchText) {
                    if let classObj = dataStore.getClass(id: student.classId) {
                        return SearchResult(student: student, className: classObj.name)
                    }
                }
                return nil
            }
            // Begrenze auf maximal 10 Ergebnisse
            searchResults = Array(matches.prefix(10))
        } else {
            // Ab 3 Buchstaben: Normale Suche mit containment
            let searchText = text.lowercased()
            let matches = allStudents.compactMap { student in
                if student.firstName.lowercased().contains(searchText) ||
                   student.lastName.lowercased().contains(searchText) {
                    if let classObj = dataStore.getClass(id: student.classId) {
                        return SearchResult(student: student, className: classObj.name)
                    }
                }
                return nil
            }
            // Sortierung nach Relevanz
            searchResults = matches.sorted { (result1, result2) -> Bool in
                // Exakte Übereinstimmungen bevorzugen
                let r1FirstNameMatch = result1.student.firstName.lowercased() == searchText
                let r1LastNameMatch = result1.student.lastName.lowercased() == searchText
                let r2FirstNameMatch = result2.student.firstName.lowercased() == searchText
                let r2LastNameMatch = result2.student.lastName.lowercased() == searchText

                if (r1FirstNameMatch || r1LastNameMatch) && !(r2FirstNameMatch || r2LastNameMatch) {
                    return true
                }
                if !(r1FirstNameMatch || r1LastNameMatch) && (r2FirstNameMatch || r2LastNameMatch) {
                    return false
                }

                // Alphabetisch sortieren
                return result1.student.sortableName < result2.student.sortableName
            }
            // Begrenze auf 20 Ergebnisse für bessere Performance
            if searchResults.count > 20 {
                searchResults = Array(searchResults.prefix(20))
            }
        }

        print("DEBUG: Suche nach '\(text)' ergab \(searchResults.count) Ergebnisse.")
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

    func validateMoveStudents(studentIds: [UUID], toClassId: UUID) -> String? {
        // Prüfen, ob die Zielklasse voll ist
        let currentStudentCount = getStudentCountForClass(classId: toClassId)
        if currentStudentCount + studentIds.count > 40 {
            return "Die Zielklasse hat nur Platz für \(40 - currentStudentCount) weitere Schüler. Sie haben \(studentIds.count) Schüler ausgewählt."
        }

        // Prüfen auf doppelte Namen
        var duplicateNames: [String] = []
        for studentId in studentIds {
            if let student = dataStore.getStudent(id: studentId) {
                if !dataStore.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: toClassId, exceptStudentId: student.id) {
                    duplicateNames.append("\(student.firstName) \(student.lastName)")
                }
            }
        }

        if !duplicateNames.isEmpty {
            let namesStr = duplicateNames.joined(separator: ", ")
            return "Folgende Schüler existieren bereits in der Zielklasse: \(namesStr)"
        }

        return nil // Keine Fehler gefunden
    }

}
