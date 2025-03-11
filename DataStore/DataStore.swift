import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var classes: [Class] = []
    @Published var students: [Student] = []
    @Published var seatingPositions: [SeatingPosition] = []

    private let classesKey = "hero4_classes"
    private let studentsKey = "hero4_students"
    private let seatingPositionsKey = "hero4_seating_positions"

    private init() {
        loadAllData()
    }

    // MARK: - Daten laden/speichern

    func loadAllData() {
        loadClasses()
        loadStudents()
        loadSeatingPositions()
    }

    func loadClasses() {
        if let data = UserDefaults.standard.data(forKey: classesKey) {
            do {
                let decoder = JSONDecoder()
                classes = try decoder.decode([Class].self, from: data)
                print("DEBUG DataStore: Klassen geladen: \(classes.count)")
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

    private func saveClasses() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(classes)
            UserDefaults.standard.set(data, forKey: classesKey)
            print("DEBUG DataStore: Klassen gespeichert: \(classes.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Klassen: \(error)")
        }
    }

    private func saveStudents() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(students)
            UserDefaults.standard.set(data, forKey: studentsKey)
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
            print("DEBUG DataStore: Sitzpositionen gespeichert: \(seatingPositions.count)")
            objectWillChange.send()
        } catch {
            print("FEHLER DataStore: Fehler beim Speichern der Sitzpositionen: \(error)")
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
        saveClasses()

        // Kontrolle, ob die Klasse korrekt hinzugefügt wurde
        if let addedClass = classes.first(where: { $0.id == newClass.id }) {
            print("DEBUG DataStore: Klasse wurde erfolgreich hinzugefügt: \(addedClass.name)")
        } else {
            print("FEHLER DataStore: Klasse wurde nicht korrekt hinzugefügt!")
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

        saveClasses()
        saveStudents()
        saveSeatingPositions()

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

        // Nur wenn wir tatsächlich Klassen haben, fügen wir auch Beispielschüler hinzu
        if !classes.isEmpty {
            addSampleStudents()
        }

        print("DEBUG DataStore: Beispieldaten hinzugefügt.")
    }

    func addSampleStudents() {
        // Nehmen wir die erste Klasse als Beispiel
        if let firstClass = classes.first {
            let sampleStudents = [
                Student(firstName: "Max", lastName: "Mustermann", classId: firstClass.id),
                Student(firstName: "Anna", lastName: "Schmidt", classId: firstClass.id),
                Student(firstName: "Paul", lastName: "Meyer", classId: firstClass.id),
                Student(firstName: "Sophie", lastName: "Müller", classId: firstClass.id),
                Student(firstName: "Tom", lastName: "Schulz", classId: firstClass.id)
            ]

            for student in sampleStudents {
                addStudent(student)

                // Auch eine zufällige Sitzposition hinzufügen
                let xPos = Int.random(in: 1...5)
                let yPos = Int.random(in: 1...5)

                let position = SeatingPosition(
                    studentId: student.id,
                    classId: firstClass.id,
                    xPos: xPos,
                    yPos: yPos
                )

                addSeatingPosition(position)
            }

            print("DEBUG DataStore: \(sampleStudents.count) Beispielschüler und Sitzpositionen für Klasse \(firstClass.name) hinzugefügt.")
        }
    }
}
