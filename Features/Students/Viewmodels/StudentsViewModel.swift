import Foundation
import SwiftUI
import Combine

class StudentsViewModel: ObservableObject {
    // Operation type for multi-select
    enum MultiSelectOperation {
        case none, delete, archive, move
    }
    
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var students: [Student] = []
    @Published var filteredStudents: [Student] = []
    @Published var allStudents: [Student] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var globalSearchText: String = ""
    @Published var searchResults: [SearchResult] = []
    // Current multi-select operation
    var multiSelectOperation: MultiSelectOperation = .none

    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var studentStatusManager = StudentStatusManager.shared
    private var statusCancellables = Set<AnyCancellable>()

    struct SearchResult: Identifiable {
        var id: UUID { student.id }
        var student: Student
        var className: String
    }

    init(initialClassId: UUID? = nil) {
        self.selectedClassId = initialClassId

        // Bei Eingabe im Suchfeld Live-Filterung aktivieren
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchTerm in
                self?.filterStudentsBySearchTerm(searchTerm)
            }
            .store(in: &cancellables)

        // Globale Suche
        $globalSearchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchTerm in
                self?.performGlobalSearch(searchTerm)
            }
            .store(in: &cancellables)

        // Klassen laden
        loadClasses()

        // Initial die Klassendaten laden
        if let initialClassId = initialClassId {
            self.selectClass(id: initialClassId)
        }
    }

    var classes: [Class] {
        // Nicht-archivierte Klassen, sortiert nach Zeile/Spalte
        return dataStore.classes
            .filter { !$0.isArchived }
            .sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    // MARK: - Class Operations

    func loadClasses() {
        // Lädt alle Klassen und selektiert die erste, falls keine ausgewählt ist
        if classes.isEmpty {
            selectedClass = nil
            selectedClassId = nil
        } else if selectedClassId == nil {
            // Optional: Automatisch die erste Klasse auswählen
            // selectClass(id: classes[0].id)
        } else if let classId = selectedClassId, selectedClass == nil {
            // Stellt sicher, dass selectedClass gesetzt ist, wenn selectedClassId existiert
            selectClass(id: classId)
        }
    }

    func selectClass(id: UUID) {
        // Klasse auswählen und Schüler laden
        selectedClassId = id
        selectedClass = dataStore.getClass(id: id)
        print("DEBUG StudentsViewModel: Klasse ausgewählt: \(selectedClass?.name ?? "unbekannt")")
        
        // Bei Klassenwechsel den Filter zurücksetzen
        searchText = ""
        
        // Schüler für die ausgewählte Klasse laden
        loadStudentsForSelectedClass()
    }

    // MARK: - Student Operations

    func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            filteredStudents = []
            return
        }

        isLoading = true

        // Schüler synchron laden, um Verzögerungen zu vermeiden
        // Schüler aus dem Repository laden
        let studentsForClass = self.dataStore.getStudentsForClass(classId: classId)
            .filter { !$0.isArchived }
            .sorted { $0.sortableName < $1.sortableName }
        
        self.students = studentsForClass
        
        // Bei leerem Suchfeld alle anzeigen, sonst filtern
        if self.searchText.isEmpty {
            self.filteredStudents = studentsForClass
        } else {
            self.filterStudentsBySearchTerm(self.searchText)
        }
        
        self.isLoading = false
    }

    func addStudent(_ student: Student) -> Bool {
        do {
            try student.validate()
            
            // Prüfen auf doppelte Namen
            if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId) {
                showError(message: "Ein Schüler mit dem Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return false
            }
            
            // Schüler hinzufügen und UI aktualisieren
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
            if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId, exceptStudentId: student.id) {
                showError(message: "Ein Schüler mit dem Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return
            }

            let success = dataStore.updateStudent(student)
            if success {
                loadStudentsForSelectedClass()
            } else {
                showError(message: "Fehler beim Speichern der Daten in der Datenbank.")
            }
        } catch Student.ValidationError.noName {
            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
        } catch {
            showError(message: "Fehler beim Aktualisieren des Schülers: \(error.localizedDescription)")
        }
        clearGlobalSearch()
    }

    func deleteStudent(id: UUID) {
        let success = dataStore.deleteStudent(id: id) // Löscht den Schüler aus dem DataStore
        if success {
            searchText = "" // Setzt die klassenbezogene Suche zurück
            loadStudentsForSelectedClass() // Lädt die aktualisierte Schülerliste
            clearGlobalSearch() // Setzt die globale Suche zurück, falls aktiv
            objectWillChange.send() // Informiert die UI über die Änderung
        } else {
            showError(message: "Fehler beim Löschen des Schülers")
        }
    }
    
    // Version with status reporting for EditStudentView
    func deleteStudentWithStatus(id: UUID) -> Bool {
        print("DEBUG StudentsViewModel: Deleting student with ID \(id)")
        let success = dataStore.deleteStudent(id: id)
        if success {
            searchText = ""
            loadStudentsForSelectedClass()
            clearGlobalSearch()
            objectWillChange.send()
            print("DEBUG StudentsViewModel: Student deleted successfully")
        } else {
            showError(message: "Fehler beim Löschen des Schülers")
            print("DEBUG StudentsViewModel: Failed to delete student")
        }
        return success
    }

    func archiveStudent(_ student: Student) {
        let success = dataStore.archiveStudent(student)
        if success {
            loadStudentsForSelectedClass()
            clearGlobalSearch()
        } else {
            showError(message: "Fehler beim Archivieren des Schülers")
        }
    }
    
    // Version with status reporting for EditStudentView
    func archiveStudentWithStatus(_ student: Student) -> Bool {
        let success = dataStore.archiveStudent(student)
        if success {
            loadStudentsForSelectedClass()
            clearGlobalSearch()
        } else {
            showError(message: "Fehler beim Archivieren des Schülers")
        }
        return success
    }

    func moveStudentToClass(studentId: UUID, newClassId: UUID) {
        guard let student = dataStore.getStudent(id: studentId) else {
            showError(message: "Schüler nicht gefunden.")
            return
        }

        let oldClassId = student.classId

        // Prüfen, ob der Name in der Zielklasse eindeutig ist
        if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: newClassId) {
            showError(message: "In der Zielklasse existiert bereits ein Schüler mit diesem Namen.")
            return
        }

        // Prüfen, ob die Zielklasse das Limit erreicht hat
        let currentCount = getStudentCountForClass(classId: newClassId)
        if currentCount >= 40 {
            showError(message: "Die Zielklasse hat bereits 40 Schüler. Es können keine weiteren Schüler hinzugefügt werden.")
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
        let success = dataStore.updateStudent(updatedStudent)
        if !success {
            showError(message: "Fehler beim Verschieben des Schülers in die neue Klasse.")
            return
        }

        // UI aktualisieren
        loadStudentsForSelectedClass()
        clearGlobalSearch()
    }

    // MARK: - Batch Operations

    func deleteMultipleStudentsWithStatus(studentIds: [UUID]) -> Bool {
        var successCount = 0
        var failCount = 0

        // Jeden Schüler einzeln löschen und Erfolg/Misserfolg zählen
        for studentId in studentIds {
            let success = dataStore.deleteStudent(id: studentId)
            if success {
                successCount += 1
            } else {
                failCount += 1
            }
        }

        // UI aktualisieren
        loadStudentsForSelectedClass()
        clearGlobalSearch()

        // Feedback anzeigen
        if failCount > 0 {
            showError(message: "\(successCount) Schüler gelöscht, \(failCount) Schüler konnten nicht gelöscht werden.")
            return false
        }
        
        return true
    }

    func archiveMultipleStudentsWithStatus(studentIds: [UUID]) -> Bool {
        var successCount = 0
        var failCount = 0

        // Jeden Schüler einzeln archivieren und Erfolg/Misserfolg zählen
        for studentId in studentIds {
            if let student = dataStore.getStudent(id: studentId) {
                let success = dataStore.archiveStudent(student)
                if success {
                    successCount += 1
                } else {
                    failCount += 1
                }
            } else {
                failCount += 1
            }
        }

        // UI aktualisieren
        loadStudentsForSelectedClass()
        clearGlobalSearch()

        // Feedback anzeigen
        if failCount > 0 {
            showError(message: "\(successCount) Schüler archiviert, \(failCount) Schüler konnten nicht archiviert werden.")
            return false
        }
        
        return true
    }

    // MARK: - Search and Filter

    private func filterStudentsBySearchTerm(_ searchTerm: String) {
        if searchTerm.isEmpty {
            filteredStudents = students
            return
        }

        let lowercaseSearchTerm = searchTerm.lowercased()
        
        // Verbesserte Suchlogik, die von der Länge des Suchbegriffs abhängt
        if lowercaseSearchTerm.count == 1 {
            // Bei einem einzelnen Zeichen nur Übereinstimmungen am Anfang von Vor- oder Nachnamen suchen
            filteredStudents = students.filter { student in
                let firstName = student.firstName.lowercased()
                let lastName = student.lastName.lowercased()
                
                // Prüfen, ob ein Vorname aus mehreren Wörtern besteht
                let firstNameComponents = firstName.components(separatedBy: " ")
                let firstNameMatches = firstNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                // Prüfen, ob ein Nachname aus mehreren Wörtern besteht
                let lastNameComponents = lastName.components(separatedBy: " ")
                let lastNameMatches = lastNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                return firstNameMatches || lastNameMatches
            }
        } else if lowercaseSearchTerm.count == 2 {
            // Bei zwei Zeichen auch Übereinstimmungen am Anfang von Vor- oder Nachnamen suchen
            filteredStudents = students.filter { student in
                let firstName = student.firstName.lowercased()
                let lastName = student.lastName.lowercased()
                
                // Prüfen, ob ein Vorname aus mehreren Wörtern besteht
                let firstNameComponents = firstName.components(separatedBy: " ")
                let firstNameMatches = firstNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                // Prüfen, ob ein Nachname aus mehreren Wörtern besteht
                let lastNameComponents = lastName.components(separatedBy: " ")
                let lastNameMatches = lastNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                return firstNameMatches || lastNameMatches
            }
        } else {
            // Bei 3+ Zeichen vollständige Teilstring-Suche
            filteredStudents = students.filter { student in
                let fullName = "\(student.firstName) \(student.lastName)".lowercased()
                return fullName.contains(lowercaseSearchTerm) ||
                      student.firstName.lowercased().contains(lowercaseSearchTerm) ||
                      student.lastName.lowercased().contains(lowercaseSearchTerm)
            }
        }
        
        // Sortieren nach Relevanz: Übereinstimmungen am Wortanfang vor Übereinstimmungen in der Mitte
        filteredStudents.sort { a, b in
            let firstNameA = a.firstName.lowercased()
            let firstNameB = b.firstName.lowercased()
            let lastNameA = a.lastName.lowercased()
            let lastNameB = b.lastName.lowercased()
            
            // 1. Priorität: Vornamen die mit dem Suchbegriff beginnen
            let aFirstNameStarts = firstNameA.hasPrefix(lowercaseSearchTerm)
            let bFirstNameStarts = firstNameB.hasPrefix(lowercaseSearchTerm)
            if aFirstNameStarts != bFirstNameStarts {
                return aFirstNameStarts
            }
            
            // 2. Priorität: Nachnamen die mit dem Suchbegriff beginnen
            let aLastNameStarts = lastNameA.hasPrefix(lowercaseSearchTerm)
            let bLastNameStarts = lastNameB.hasPrefix(lowercaseSearchTerm)
            if aLastNameStarts != bLastNameStarts {
                return aLastNameStarts
            }
            
            // 3. Alphabetisch nach Nachname, dann Vorname
            if lastNameA != lastNameB {
                return lastNameA < lastNameB
            }
            
            return firstNameA < firstNameB
        }
    }

    func updateGlobalSearchText(_ searchTerm: String) {
        globalSearchText = searchTerm
        performGlobalSearch(searchTerm)
    }

    private func performGlobalSearch(_ searchTerm: String) {
        if searchTerm.isEmpty {
            searchResults = []
            return
        }

        let lowercaseSearchTerm = searchTerm.lowercased()
        
        // Alle Klassen laden
        let allClasses = dataStore.classes.filter { !$0.isArchived }
        let classMap = Dictionary(uniqueKeysWithValues: allClasses.map { ($0.id, $0) })
        
        // Alle Schüler laden (nicht archivierte)
        allStudents = dataStore.students.filter { !$0.isArchived }
        
        // Verbesserte Suchlogik basierend auf Länge des Suchbegriffs
        var matchingStudents: [Student] = []
        
        if lowercaseSearchTerm.count == 1 {
            // Bei 1 Buchstabe nur exakte Übereinstimmungen am Anfang von Vor- oder Nachnamen
            matchingStudents = allStudents.filter { student in
                let firstName = student.firstName.lowercased()
                let lastName = student.lastName.lowercased()
                
                return firstName.hasPrefix(lowercaseSearchTerm) || 
                       lastName.hasPrefix(lowercaseSearchTerm)
            }
        } else if lowercaseSearchTerm.count == 2 {
            // Bei 2 Buchstaben nur exakte Übereinstimmungen am Anfang von Vor- oder Nachnamen
            // und auch im zweiten Wort nach Leerzeichen
            matchingStudents = allStudents.filter { student in
                let firstName = student.firstName.lowercased()
                let lastName = student.lastName.lowercased()
                
                // Prüfen, ob ein Vorname aus mehreren Wörtern besteht
                let firstNameComponents = firstName.components(separatedBy: " ")
                let firstNameMatches = firstNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                // Prüfen, ob ein Nachname aus mehreren Wörtern besteht
                let lastNameComponents = lastName.components(separatedBy: " ")
                let lastNameMatches = lastNameComponents.contains { 
                    $0.hasPrefix(lowercaseSearchTerm) 
                }
                
                return firstNameMatches || lastNameMatches
            }
        } else {
            // Bei 3+ Buchstaben alle Teilstring-Übereinstimmungen
            matchingStudents = allStudents.filter { student in
                let fullName = "\(student.firstName) \(student.lastName)".lowercased()
                return fullName.contains(lowercaseSearchTerm) ||
                      student.firstName.lowercased().contains(lowercaseSearchTerm) ||
                      student.lastName.lowercased().contains(lowercaseSearchTerm)
            }
        }
        
        // Zu SearchResults konvertieren
        searchResults = matchingStudents.map { student in
            let className = classMap[student.classId]?.name ?? "Unbekannte Klasse"
            return SearchResult(student: student, className: className)
        }
        
        // Nach Relevanz sortieren
        searchResults.sort { a, b in
            let firstNameA = a.student.firstName.lowercased()
            let firstNameB = b.student.firstName.lowercased()
            let lastNameA = a.student.lastName.lowercased()
            let lastNameB = b.student.lastName.lowercased()
            
            // 1. Priorität: Vornamen die mit dem Suchbegriff beginnen
            let aFirstNameStarts = firstNameA.hasPrefix(lowercaseSearchTerm)
            let bFirstNameStarts = firstNameB.hasPrefix(lowercaseSearchTerm)
            if aFirstNameStarts != bFirstNameStarts {
                return aFirstNameStarts
            }
            
            // 2. Priorität: Nachnamen die mit dem Suchbegriff beginnen
            let aLastNameStarts = lastNameA.hasPrefix(lowercaseSearchTerm)
            let bLastNameStarts = lastNameB.hasPrefix(lowercaseSearchTerm)
            if aLastNameStarts != bLastNameStarts {
                return aLastNameStarts
            }
            
            // 3. Nach Klasse sortieren
            if a.className != b.className {
                return a.className < b.className
            }
            
            // 4. Alphabetisch nach Nachname, dann Vorname
            if lastNameA != lastNameB {
                return lastNameA < lastNameB
            }
            
            return firstNameA < firstNameB
        }
    }

    func clearGlobalSearch() {
        globalSearchText = ""
        searchResults = []
    }

    // MARK: - Helper Methods

    func showError(message: String) {
        errorMessage = message
        showError = true
        print("ERROR StudentsViewModel: \(message)")
    }

    func getStudentCountForClass(classId: UUID) -> Int {
        return dataStore.getStudentsForClass(classId: classId)
            .filter { !$0.isArchived }
            .count
    }
    
    // WICHTIG: Diese Funktion sichert zusätzlich ab, dass der Student wirklich existiert
    // Wird für die verbesserte Fehlerbehandlung bei der Schülerauswahl verwendet
    func verifyAndGetStudent(id: UUID) -> Student? {
        if let student = dataStore.getStudent(id: id) {
            print("DEBUG: Student \(id) erfolgreich verifiziert")
            return student
        } else {
            print("ERROR: Student \(id) nicht in der Datenbank gefunden!")
            return nil
        }
    }

    func isStudentNameUnique(firstName: String, lastName: String, classId: UUID, exceptStudentId: UUID? = nil) -> Bool {
        // Hilfsmethode zur Prüfung, ob ein Name in einer Klasse eindeutig ist
        let normalizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let studentsInClass = dataStore.getStudentsForClass(classId: classId)
            .filter { !$0.isArchived }
        
        return !studentsInClass.contains { student in
            // Aktuellen Schüler bei Updates ausschließen
            if let exceptId = exceptStudentId, student.id == exceptId {
                return false
            }
            
            // Normalisierte Namen vergleichen
            let existingFirstName = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let existingLastName = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            return existingFirstName == normalizedFirstName && existingLastName == normalizedLastName
        }
    }

    func validateMoveStudents(studentIds: [UUID], toClassId: UUID) -> String? {
        // Prüft, ob alle ausgewählten Schüler in die Zielklasse verschoben werden können
        
        // Anzahl der Schüler in der Zielklasse
        let currentCount = getStudentCountForClass(classId: toClassId)
        let selectedCount = studentIds.count
        
        // Prüfen, ob das Limit überschritten wird
        if currentCount + selectedCount > 40 {
            return "In der Zielklasse sind bereits \(currentCount) Schüler. Mit den \(selectedCount) ausgewählten Schülern würde das Limit von 40 überschritten."
        }
        
        // Prüfen, ob Namensduplikate existieren
        var duplicateNames: [String] = []
        for studentId in studentIds {
            if let student = dataStore.getStudent(id: studentId) {
                if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: toClassId) {
                    duplicateNames.append("\(student.firstName) \(student.lastName)")
                }
            }
        }
        
        if !duplicateNames.isEmpty {
            let nameList = duplicateNames.joined(separator: ", ")
            return "Die folgenden Schüler existieren bereits in der Zielklasse: \(nameList)"
        }
        
        return nil
    }

    func moveStudentToClassWithStatus(studentId: UUID, newClassId: UUID) {
        guard let student = dataStore.getStudent(id: studentId) else {
            print("ERROR StudentsViewModel: Schüler mit ID \(studentId) nicht gefunden")
            return
        }
        
        // Schüler verschieben
        var updatedStudent = student
        updatedStudent.classId = newClassId
        let success = dataStore.updateStudent(updatedStudent)
        
        if !success {
            print("ERROR StudentsViewModel: Fehler beim Verschieben von Schüler \(student.fullName)")
        }
    }
}