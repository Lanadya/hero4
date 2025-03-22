import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var classes: [Class] = []
    @Published var students: [Student] = []
    @Published var seatingPositions: [SeatingPosition] = []
    @Published var absenceStatuses: [UUID: Bool] = [:] // Neue Property für Abwesenheitsstatus
    @Published var ratings: [Rating] = []

    private let classesKey = "hero4_classes"
    private let studentsKey = "hero4_students"
    private let seatingPositionsKey = "hero4_seating_positions"
    private let absenceStatusesKey = "hero4_absence_statuses" // Neuer Key für Speicherung
    private let ratingsKey = "hero4_ratings"


    private init() {
        loadAllData()
    }

    // MARK: - Daten laden/speichern

    func loadAllData() {
        loadClasses()
        loadStudents()
        loadSeatingPositions()
        loadAbsenceStatuses()
        loadRatings()
    }

    func loadClasses() {
        if let data = UserDefaults.standard.data(forKey: classesKey) {
            do {
                let decoder = JSONDecoder()
                // Wichtig: Für das korrekte Decodieren von Date müssen wir die Datumsstrategie setzen
                decoder.dateDecodingStrategy = .iso8601
                classes = try decoder.decode([Class].self, from: data)
                print("DEBUG DataStore: Klassen geladen: \(classes.count)")

                // Zusätzliche Debug-Informationen
                if !classes.isEmpty {
                    for (index, classObj) in classes.enumerated() {
                        print("DEBUG DataStore: Geladene Klasse \(index): \(classObj.name) an (\(classObj.row), \(classObj.column)) mit ID \(classObj.id)")
                    }
                }
            } catch {
                print("FEHLER DataStore: Fehler beim Laden der Klassen: \(error)")
                classes = []
            }
        } else {
            print("DEBUG DataStore: Keine gespeicherten Klassen gefunden.")
            classes = []
        }

        objectWillChange.send()
    }

    func loadStudents() {
        if let data = UserDefaults.standard.data(forKey: studentsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                students = try decoder.decode([Student].self, from: data)
                print("DEBUG DataStore: Schüler geladen: \(students.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Laden der Schüler: \(error)")
                students = []
            }
        } else {
            print("DEBUG DataStore: Keine gespeicherten Schüler gefunden.")
            students = []
        }

        objectWillChange.send()
    }

    func loadSeatingPositions() {
        if let data = UserDefaults.standard.data(forKey: seatingPositionsKey) {
            do {
                let decoder = JSONDecoder()
                seatingPositions = try decoder.decode([SeatingPosition].self, from: data)
                print("DEBUG DataStore: Sitzpositionen geladen: \(seatingPositions.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Laden der Sitzpositionen: \(error)")
                seatingPositions = []
            }
        } else {
            print("DEBUG DataStore: Keine gespeicherten Sitzpositionen gefunden.")
            seatingPositions = []
        }

        objectWillChange.send()
    }

    // Neue Funktion zum Laden der Abwesenheitsstatus
    func loadAbsenceStatuses() {
        if let data = UserDefaults.standard.data(forKey: absenceStatusesKey) {
            do {
                let decoder = JSONDecoder()
                absenceStatuses = try decoder.decode([UUID: Bool].self, from: data)
                print("DEBUG DataStore: Abwesenheitsstatus geladen: \(absenceStatuses.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Laden der Abwesenheitsstatus: \(error)")
                absenceStatuses = [:]
            }
        } else {
            print("DEBUG DataStore: Keine gespeicherten Abwesenheitsstatus gefunden.")
            absenceStatuses = [:]
        }

        objectWillChange.send()
    }

    private func saveClasses() {
        do {
            let encoder = JSONEncoder()
            // Wichtig: Für das korrekte Encodieren von Date müssen wir die Datumsstrategie setzen
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(classes)

            // Debug: Zeige die JSON-Repräsentation der Klassen an
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG DataStore: JSON für Klassen: \(jsonString)")
            }

            UserDefaults.standard.set(data, forKey: classesKey)
            print("DEBUG DataStore: Klassen gespeichert: \(classes.count)")

            // Erzwingen Sie, dass UserDefaults sofort synchronisiert werden
            UserDefaults.standard.synchronize()

            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Klassen: \(error)")
        }
    }

    private func saveStudents() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(students)
            UserDefaults.standard.set(data, forKey: studentsKey)
            UserDefaults.standard.synchronize()
            print("DEBUG DataStore: Schüler gespeichert: \(students.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Schüler: \(error)")
        }
    }

    private func saveSeatingPositions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(seatingPositions)
            UserDefaults.standard.set(data, forKey: seatingPositionsKey)
            UserDefaults.standard.synchronize()
            print("DEBUG DataStore: Sitzpositionen gespeichert: \(seatingPositions.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Sitzpositionen: \(error)")
        }
    }

    // Neue Funktion zum Speichern der Abwesenheitsstatus
    private func saveAbsenceStatuses() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(absenceStatuses)
            UserDefaults.standard.set(data, forKey: absenceStatusesKey)
            UserDefaults.standard.synchronize()
            print("DEBUG DataStore: Abwesenheitsstatus gespeichert: \(absenceStatuses.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Abwesenheitsstatus: \(error)")
        }
    }

    // MARK: - Klassen-Operationen

    func addClass(_ class: Class) {
        print("DEBUG DataStore: Füge Klasse hinzu: \(`class`.name) an Position (\(`class`.row), \(`class`.column))")

        // Stellen wir sicher, dass die Klasse ein gültiges, eindeutiges ID hat
        let newClass = Class(
            id: `class`.id,  // Behalte die ID bei
            name: `class`.name,
            note: `class`.note,
            row: `class`.row,
            column: `class`.column,
            maxRatingValue: `class`.maxRatingValue,
            isArchived: `class`.isArchived,
            createdAt: `class`.createdAt,
            modifiedAt: `class`.modifiedAt
        )

        print("DEBUG DataStore: Neue Klasse ID: \(newClass.id)")

        // Hinzufügen und speichern
        classes.append(newClass)

        // Wichtig: Speichern Sie die Klassen direkt nach dem Hinzufügen
        saveClasses()

        // Kontrolle, ob die Klasse korrekt hinzugefügt wurde
        if let addedClass = classes.first(where: { $0.id == newClass.id }) {
            print("DEBUG DataStore: Klasse wurde erfolgreich hinzugefügt: \(addedClass.name)")
        } else {
            print("FEHLER DataStore: Klasse wurde nicht korrekt hinzugefügt!")
        }

        // Nachprüfung, ob die Daten tatsächlich gespeichert wurden
        verifyClassesSaved()
    }

    // Hilfsmethode zur Überprüfung, ob Klassen tatsächlich gespeichert wurden
    private func verifyClassesSaved() {
        if let data = UserDefaults.standard.data(forKey: classesKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let savedClasses = try decoder.decode([Class].self, from: data)
                print("DEBUG DataStore: Verifikation - \(savedClasses.count) Klassen in UserDefaults gefunden")
            } catch {
                print("FEHLER DataStore: Verifikation fehlgeschlagen: \(error)")
            }
        } else {
            print("FEHLER DataStore: Verifikation fehlgeschlagen - Keine Daten in UserDefaults")
        }
    }

    func updateClass(_ class: Class) {
        if let index = classes.firstIndex(where: { $0.id == `class`.id }) {
            classes[index] = `class`
            saveClasses()
            print("DEBUG DataStore: Klasse aktualisiert: \(`class`.name) an Position (\(`class`.row), \(`class`.column))")
        } else {
            print("FEHLER DataStore: Konnte Klasse mit ID \(`class`.id) nicht finden.")
        }
    }

    func deleteClass(id: UUID) {
        if let index = classes.firstIndex(where: { $0.id == id }) {
            let classToDelete = classes[index]
            print("DEBUG DataStore: Lösche Klasse: \(classToDelete.name) an Position (\(classToDelete.row), \(classToDelete.column))")
            classes.remove(at: index)
            saveClasses()

            // Wenn eine Klasse gelöscht wird, sollten auch alle zugehörigen Schüler und Sitzpositionen gelöscht werden
            deleteStudentsForClass(classId: id)
            deleteSeatingPositionsForClass(classId: id)
        } else {
            print("FEHLER DataStore: Konnte Klasse mit ID \(id) nicht zum Löschen finden.")
        }
    }

    func getClass(id: UUID) -> Class? {
        return classes.first { $0.id == id }
    }

    func getClassAt(row: Int, column: Int) -> Class? {
        // Überprüfe, ob die Position gültig ist
        if row < 1 || row > 12 || column < 1 || column > 5 {
            print("DEBUG DataStore: Ungültige Position für Klassenabfrage: (\(row), \(column))")
            return nil
        }

        let result = classes.first {
            $0.row == row &&
            $0.column == column &&
            !$0.isArchived
        }

        if result != nil {
            print("DEBUG DataStore: Klasse an Position (\(row), \(column)) gefunden: \(result!.name)")
        } else {
            print("DEBUG DataStore: Keine Klasse an Position (\(row), \(column)) gefunden")
        }

        return result
    }

    func archiveClass(_ class: Class) {
        var updatedClass = `class`
        updatedClass.isArchived = true
        print("DEBUG DataStore: Archiviere Klasse: \(updatedClass.name) an Position (\(updatedClass.row), \(updatedClass.column))")
        updateClass(updatedClass)
    }

    func validateClassPositionIsAvailable(row: Int, column: Int, exceptClassId: UUID? = nil) -> Bool {
        // Überprüfe, ob die Position gültig ist
        if row < 1 || row > 12 || column < 1 || column > 5 {
            print("DEBUG DataStore: Position (\(row), \(column)) ist außerhalb des gültigen Bereichs.")
            return false
        }

        // Prüfe, ob an dieser Position bereits eine Klasse ist (außer der Klasse mit exceptClassId)
        if let existingClass = getClassAt(row: row, column: column),
           existingClass.id != exceptClassId {
            print("DEBUG DataStore: Position (\(row), \(column)) ist bereits durch Klasse \(existingClass.name) belegt.")
            return false
        }

        print("DEBUG DataStore: Position (\(row), \(column)) ist verfügbar.")
        return true
    }

    // MARK: - Validierung für doppelte Klassennamen

    /// Prüft, ob ein Klassenname bereits existiert (exakt gleicher Name)
    func isClassNameUnique(_ name: String, exceptClassId: UUID? = nil) -> Bool {
        let matchingClasses = classes.filter {
            !$0.isArchived &&
            $0.name.lowercased() == name.lowercased() &&
            $0.id != exceptClassId
        }

        return matchingClasses.isEmpty
    }

    /// Prüft, ob ein ähnlicher Klassenname bereits existiert (für Warnungen)
    func findSimilarClassNames(_ name: String, exceptClassId: UUID? = nil) -> [String] {
        let lowercaseName = name.lowercased()

        return classes.filter {
            !$0.isArchived &&
            $0.name.lowercased().contains(lowercaseName) &&
            $0.id != exceptClassId
        }.map { $0.name }
    }

    // MARK: - Validierung für doppelte Schülernamen

    /// Prüft, ob der Name eines Schülers bereits in der Klasse existiert
    func isStudentNameUnique(firstName: String, lastName: String, classId: UUID, exceptStudentId: UUID? = nil) -> Bool {
        // Normalisiere die Namen für den Vergleich
        let normalizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Suche nach Schülern mit gleichem Namen in der gleichen Klasse
        let duplicates = students.filter { student in
            // Ignoriere den angegebenen Schüler selbst (für Edit-Fälle)
            if let exceptId = exceptStudentId, student.id == exceptId {
                return false
            }

            // Gleiche Klasse?
            if student.classId != classId || student.isArchived {
                return false
            }

            // Vergleiche normalisierte Namen
            let studentFirstName = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let studentLastName = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            return studentFirstName == normalizedFirstName && studentLastName == normalizedLastName
        }

        // Wenn keine Duplikate gefunden wurden, ist der Name eindeutig
        return duplicates.isEmpty
    }

    // MARK: - Schüler-Operationen

    func addStudent(_ student: Student) {
        print("DEBUG DataStore: Füge Schüler hinzu: \(student.fullName)")
        students.append(student)
        saveStudents()
    }

    func updateStudent(_ student: Student) {
        if let index = students.firstIndex(where: { $0.id == student.id }) {
            students[index] = student
            saveStudents()
            print("DEBUG DataStore: Schüler aktualisiert: \(student.fullName)")
        } else {
            print("FEHLER DataStore: Konnte Schüler mit ID \(student.id) nicht finden.")
        }
    }

    func deleteStudent(id: UUID) {
        if let index = students.firstIndex(where: { $0.id == id }) {
            let studentToDelete = students[index]
            print("DEBUG DataStore: Lösche Schüler: \(studentToDelete.fullName)")
            students.remove(at: index)
            saveStudents()

            // Auch alle Sitzpositionen für diesen Schüler löschen
            deleteSeatingPositionsForStudent(studentId: id)

            // Abwesenheitsstatus löschen
            if absenceStatuses[id] != nil {
                absenceStatuses.removeValue(forKey: id)
                saveAbsenceStatuses()
            }
        } else {
            print("FEHLER DataStore: Konnte Schüler mit ID \(id) nicht zum Löschen finden.")
        }
    }

    func deleteStudentsForClass(classId: UUID) {
        // Filtere alle Schüler der angegebenen Klasse
        let studentsToDelete = students.filter { $0.classId == classId }

        // Lösche jeden Schüler
        for student in studentsToDelete {
            deleteStudent(id: student.id)
        }

        print("DEBUG DataStore: \(studentsToDelete.count) Schüler der Klasse mit ID \(classId) gelöscht.")
    }

    func getStudent(id: UUID) -> Student? {
        return students.first { $0.id == id }
    }

    func getStudentsForClass(classId: UUID, includeArchived: Bool = false) -> [Student] {
        return students.filter {
            $0.classId == classId && (includeArchived || !$0.isArchived)
        }.sorted { $0.sortableName < $1.sortableName }
    }

    func archiveStudent(_ student: Student) {
        var updatedStudent = student
        updatedStudent.isArchived = true
        print("DEBUG DataStore: Archiviere Schüler: \(updatedStudent.fullName)")
        updateStudent(updatedStudent)
    }

    // MARK: - Abwesenheitsstatus-Operationen

    func updateStudentAbsenceStatus(studentId: UUID, isAbsent: Bool) {
        absenceStatuses[studentId] = isAbsent
        saveAbsenceStatuses()
        print("DEBUG DataStore: Abwesenheitsstatus für Schüler \(studentId) auf \(isAbsent) gesetzt")
    }

    func isStudentAbsent(_ studentId: UUID) -> Bool {
        return absenceStatuses[studentId] ?? false
    }

    // MARK: - Sitzpositionen-Operationen

    func addSeatingPosition(_ position: SeatingPosition) {
        print("DEBUG DataStore: Füge Sitzposition hinzu für Schüler mit ID \(position.studentId)")

        // Überprüfen, ob bereits eine Position für diesen Schüler in dieser Klasse existiert
        if let existingIndex = seatingPositions.firstIndex(where: {
            $0.studentId == position.studentId && $0.classId == position.classId
        }) {
            // Wenn ja, aktualisiere diese Position
            seatingPositions[existingIndex] = position
            print("DEBUG DataStore: Bestehende Sitzposition aktualisiert.")
        } else {
            // Wenn nein, füge eine neue Position hinzu
            seatingPositions.append(position)
            print("DEBUG DataStore: Neue Sitzposition hinzugefügt.")
        }

        saveSeatingPositions()
    }

    func updateSeatingPosition(_ position: SeatingPosition) {
        if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
            seatingPositions[index] = position
            saveSeatingPositions()
            print("DEBUG DataStore: Sitzposition aktualisiert für Schüler mit ID \(position.studentId)")
        } else {
            print("FEHLER DataStore: Konnte Sitzposition mit ID \(position.id) nicht finden.")
        }
    }

    func deleteSeatingPosition(id: UUID) {
        if let index = seatingPositions.firstIndex(where: { $0.id == id }) {
            let positionToDelete = seatingPositions[index]
            print("DEBUG DataStore: Lösche Sitzposition für Schüler mit ID \(positionToDelete.studentId)")
            seatingPositions.remove(at: index)
            saveSeatingPositions()
        } else {
            print("FEHLER DataStore: Konnte Sitzposition mit ID \(id) nicht zum Löschen finden.")
        }
    }

    func deleteSeatingPositionsForStudent(studentId: UUID) {
        // Filtere alle Positionen für den angegebenen Schüler
        let positionsToDelete = seatingPositions.filter { $0.studentId == studentId }

        // Lösche jede Position
        for position in positionsToDelete {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions.remove(at: index)
            }
        }

        if !positionsToDelete.isEmpty {
            saveSeatingPositions()
            print("DEBUG DataStore: \(positionsToDelete.count) Sitzpositionen für Schüler mit ID \(studentId) gelöscht.")
        }
    }

    func deleteSeatingPositionsForClass(classId: UUID) {
        // Filtere alle Positionen für die angegebene Klasse
        let positionsToDelete = seatingPositions.filter { $0.classId == classId }

        // Lösche jede Position
        for position in positionsToDelete {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions.remove(at: index)
            }
        }

        if !positionsToDelete.isEmpty {
            saveSeatingPositions()
            print("DEBUG DataStore: \(positionsToDelete.count) Sitzpositionen für Klasse mit ID \(classId) gelöscht.")
        }
    }

    func getSeatingPosition(studentId: UUID, classId: UUID) -> SeatingPosition? {
        return seatingPositions.first {
            $0.studentId == studentId && $0.classId == classId
        }
    }

    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition] {
        return seatingPositions.filter { $0.classId == classId }
    }

    // MARK: - Debugging-Funktionen

    func resetAllData() {
        classes = []
        students = []
        seatingPositions = []
        absenceStatuses = [:]
        ratings = []

        saveClasses()
        saveStudents()
        saveSeatingPositions()
        saveAbsenceStatuses()
        saveRatings()
        
        print("DEBUG DataStore: Alle Daten zurückgesetzt.")
    }

    func addSampleData() {
        // Beispielklassen hinzufügen
        let sampleClasses = [
            Class(name: "10a", note: "Mathe", row: 2, column: 1),
            Class(name: "11b", note: "Englisch", row: 3, column: 2),
            Class(name: "9c", note: "Deutsch", row: 4, column: 3),
            Class(name: "12d", row: 5, column: 4)
        ]

        for sampleClass in sampleClasses {
            if validateClassPositionIsAvailable(row: sampleClass.row, column: sampleClass.column) {
                addClass(sampleClass)
            }
        }

        // Füge Beispielschüler zu jeder Klasse hinzu
        if !classes.isEmpty {
            for classObj in classes {
                addSampleStudentsToClass(classId: classObj.id, count: 15)
            }
        }

        print("DEBUG DataStore: Beispieldaten hinzugefügt.")
    }

    func addSampleStudentsToClass(classId: UUID, count: Int = 15) {
        let firstNames = ["Max", "Anna", "Paul", "Sophie", "Tom", "Lisa", "Felix", "Sarah", "Lukas", "Lena",
                          "Jonas", "Laura", "David", "Julia", "Niklas", "Emma", "Alexander", "Mia", "Leon", "Hannah"]
        let lastNames = ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Hoffmann", "Schulz",
                         "Bauer", "Koch", "Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann", "Braun"]

        // Zufällige Auswahl von verschiedenen Namen
        for i in 0..<min(count, 40) {
            let firstName = firstNames[Int.random(in: 0..<firstNames.count)]
            let lastName = lastNames[Int.random(in: 0..<lastNames.count)]
            let note = Int.random(in: 0...5) == 0 ? "Sprachförderung" : nil  // Nur manchmal Notizen

            let student = Student(
                firstName: firstName,
                lastName: lastName,
                classId: classId,
                notes: note
            )

            addStudent(student)

            // Optional: auch eine zufällige Sitzposition hinzufügen
            let xPos = Int.random(in: 1...5)
            let yPos = Int.random(in: 1...5)

            let position = SeatingPosition(
                studentId: student.id,
                classId: classId,
                xPos: xPos,
                yPos: yPos
            )

            addSeatingPosition(position)
        }

        print("DEBUG DataStore: \(count) Beispielschüler zur Klasse mit ID \(classId) hinzugefügt")
    }


    // Diese Methoden zur DataStore.swift-Klasse hinzufügen:

    func updateSeatingPositionsInBatch(_ positions: [SeatingPosition]) {
        for position in positions {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions[index] = position
            } else {
                seatingPositions.append(position)
            }
        }
        saveSeatingPositions()
    }

    func resetSeatingPositionsForClass(classId: UUID) {
        // Löscht alle Sitzpositionen für eine Klasse
        let positionsToDelete = seatingPositions.filter { $0.classId == classId }

        for position in positionsToDelete {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions.remove(at: index)
            }
        }

        saveSeatingPositions()
    }

    func arrangeSeatingPositionsInGrid(classId: UUID, columns: Int) {
        // Ordnet Schüler automatisch in einem Raster an
        let studentsForClass = getStudentsForClass(classId: classId)
        var updatedPositions: [SeatingPosition] = []

        // Bestehende Positionen löschen
        resetSeatingPositionsForClass(classId: classId)

        // Neue Positionen in einem Raster anordnen
        for (index, student) in studentsForClass.enumerated() {
            let row = index / columns
            let col = index % columns

            let position = SeatingPosition(
                studentId: student.id,
                classId: classId,
                xPos: col,
                yPos: row,
                isCustomPosition: false
            )

            updatedPositions.append(position)
        }

        // Alle neuen Positionen in einem Rutsch speichern
        updateSeatingPositionsInBatch(updatedPositions)
    }

    // Lade-/Speicher-Methoden
    func loadRatings() {
        if let data = UserDefaults.standard.data(forKey: ratingsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                ratings = try decoder.decode([Rating].self, from: data)
                print("DEBUG DataStore: Bewertungen geladen: \(ratings.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Laden der Bewertungen: \(error)")
                ratings = []
            }
        } else {
            print("DEBUG DataStore: Keine gespeicherten Bewertungen gefunden.")
            ratings = []
        }

        objectWillChange.send()
    }

    private func saveRatings() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(ratings)
            UserDefaults.standard.set(data, forKey: ratingsKey)
            UserDefaults.standard.synchronize()
            print("DEBUG DataStore: Bewertungen gespeichert: \(ratings.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Bewertungen: \(error)")
        }
    }

    // Rating-Operationen
    func addRating(_ rating: Rating) {
        var newRating = rating
        if newRating.schoolYear.isEmpty {
            newRating.schoolYear = currentSchoolYear()
        }
        ratings.append(newRating)
        saveRatings()
        print("Neue Note für Schüler \(newRating.studentId) im Schuljahr \(newRating.schoolYear) hinzugefügt")
    }

    func updateRating(_ rating: Rating) {
        if let index = ratings.firstIndex(where: { $0.id == rating.id }) {
            ratings[index] = rating
            saveRatings()
            print("DEBUG DataStore: Bewertung aktualisiert für Schüler \(rating.studentId)")
        } else {
            print("FEHLER DataStore: Konnte Bewertung mit ID \(rating.id) nicht finden.")
        }
    }

    func deleteRating(id: UUID) {
        if let index = ratings.firstIndex(where: { $0.id == id }) {
            let ratingToDelete = ratings[index]
            ratings.remove(at: index)
            saveRatings()
            print("DEBUG DataStore: Bewertung gelöscht für Schüler \(ratingToDelete.studentId)")
        } else {
            print("FEHLER DataStore: Konnte Bewertung mit ID \(id) nicht zum Löschen finden.")
        }
    }

    func archiveRating(_ rating: Rating) {
        var updatedRating = rating
        updatedRating.isArchived = true
        updateRating(updatedRating)
        print("DEBUG DataStore: Bewertung archiviert für Schüler \(rating.studentId)")
    }

    func getRating(id: UUID) -> Rating? {
        return ratings.first { $0.id == id }
    }

    func getRatingsForStudent(studentId: UUID) -> [Rating] {
        return ratings.filter { $0.studentId == studentId && !$0.isArchived }
    }

    func getRatingsForClass(classId: UUID, includeArchived: Bool = false) -> [Rating] {
        return ratings.filter {
            $0.classId == classId && (includeArchived || !$0.isArchived)
        }
    }



}





