import Foundation
import GRDB
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore() // Singleton für einfachen Zugriff

    // Veröffentlichte Eigenschaften für SwiftUI-Binding
    @Published var classes: [Class] = []
    @Published var students: [Student] = []
    @Published var seatingPositions: [SeatingPosition] = []
    @Published var ratings: [Rating] = []

    // GRDB Datenbankzugriff
    private let dbManager = GRDBManager.shared

    private init() {
        // Beim ersten Start die Migration durchführen
        migrateFromUserDefaultsIfNeeded()

        // Initiales Laden der Daten
        loadAllData()
    }

    // MARK: - Daten laden/speichern

    func loadAllData() {
        loadClasses()
        loadStudents()
        loadSeatingPositions()
        loadRatings()
    }

    // Migration von UserDefaults zu GRDB, falls notwendig
    private func migrateFromUserDefaultsIfNeeded() {
        if !UserDefaults.standard.bool(forKey: "hasCompletedDBMigration") {
            do {
                try dbManager.migrateAllDataFromUserDefaults()
                UserDefaults.standard.set(true, forKey: "hasCompletedDBMigration")
                print("DEBUG DataStore: Datenmigration erfolgreich abgeschlossen")
            } catch {
                print("ERROR DataStore: Fehler bei der Datenmigration: \(error)")
            }
        }
    }

    // MARK: - Klassen-Operationen

        func loadClasses() {
            do {
                classes = try dbManager.fetchClasses()
                print("DEBUG DataStore: \(classes.count) Klassen geladen")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Klassen: \(error)")
                classes = []
            }
        }

        func addClass(_ class: Class) {
            do {
                let updatedClass = try dbManager.saveClass(`class`)
                classes.append(updatedClass)
                print("DEBUG DataStore: Klasse \(updatedClass.name) hinzugefügt")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Hinzufügen der Klasse: \(error)")
            }
        }

        func updateClass(_ class: Class) {
            do {
                let updatedClass = try dbManager.saveClass(`class`)
                if let index = classes.firstIndex(where: { $0.id == updatedClass.id }) {
                    classes[index] = updatedClass
                    print("DEBUG DataStore: Klasse \(updatedClass.name) aktualisiert")
                } else {
                    classes.append(updatedClass)
                    print("DEBUG DataStore: Klasse \(updatedClass.name) hinzugefügt (Update)")
                }
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Aktualisieren der Klasse: \(error)")
            }
        }

        func deleteClass(id: UUID) {
            do {
                try dbManager.deleteClass(id: id)
                if let index = classes.firstIndex(where: { $0.id == id }) {
                    let classToDelete = classes[index]
                    classes.remove(at: index)
                    print("DEBUG DataStore: Klasse \(classToDelete.name) gelöscht")
                }
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Löschen der Klasse: \(error)")
            }
        }

        func getClass(id: UUID) -> Class? {
            if let cachedClass = classes.first(where: { $0.id == id }) {
                return cachedClass
            }

            do {
                if let dbClass = try dbManager.fetchClass(id: id) {
                    return dbClass
                }
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Klasse: \(error)")
            }

            return nil
        }

        func getClassAt(row: Int, column: Int) -> Class? {
            // Zuerst im Cache suchen
            let cachedClass = classes.first {
                $0.row == row &&
                $0.column == column &&
                !$0.isArchived
            }

            if let foundClass = cachedClass {
                return foundClass
            }

            // Aus DB laden wenn nicht im Cache
            do {
                return try dbManager.fetchClassAt(row: row, column: column)
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Klasse an Position (\(row), \(column)): \(error)")
                return nil
            }
        }

        func archiveClass(_ class: Class) {
            var updatedClass = `class`
            updatedClass.isArchived = true
            updateClass(updatedClass)
        }

        func validateClassPositionIsAvailable(row: Int, column: Int, exceptClassId: UUID? = nil) -> Bool {
            if row < 1 || row > 12 || column < 1 || column > 5 {
                return false
            }

            if let existingClass = getClassAt(row: row, column: column),
               existingClass.id != exceptClassId {
                return false
            }

            return true
        }

        func isClassNameUnique(_ name: String, exceptClassId: UUID? = nil) -> Bool {
            return !classes.contains {
                !$0.isArchived &&
                $0.name.lowercased() == name.lowercased() &&
                $0.id != exceptClassId
            }
        }

        func findSimilarClassNames(_ name: String, exceptClassId: UUID? = nil) -> [String] {
            return classes.filter {
                !$0.isArchived &&
                $0.name.lowercased().contains(name.lowercased()) &&
                $0.id != exceptClassId
            }.map { $0.name }
        }

    // MARK: - Student Operations

    func loadStudents() {
        do {
            students = try dbManager.fetchStudents()
            print("DEBUG DataStore: \(students.count) Schüler geladen")
            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Schüler: \(error)")
            students = []
        }
    }

    func addStudent(_ student: Student) {
        do {
            // Validate the student data
            try student.validate()

            // Check for duplicate names in the same class
            if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId) {
                print("FEHLER DataStore: Schüler mit Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return
            }

            // Save to database and update memory cache
            let savedStudent = try dbManager.saveStudent(student)
            students.append(savedStudent)
            print("DEBUG DataStore: Schüler \(savedStudent.fullName) hinzugefügt")
            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Hinzufügen des Schülers: \(error)")
        }
    }

    func updateStudent(_ student: Student) -> Bool {
        do {
            try student.validate()

            let updatedStudent = try dbManager.saveStudent(student)

            if let index = students.firstIndex(where: { $0.id == updatedStudent.id }) {
                students[index] = updatedStudent
            } else {
                students.append(updatedStudent)
            }

            objectWillChange.send()
            return true
        } catch {
            print("ERROR DataStore: Failed to update student: \(error.localizedDescription)")
            return false
        }
    }

    func deleteStudent(id: UUID) -> Bool {
        do {
            // First check if the student exists
            guard let student = getStudent(id: id) else {
                print("ERROR DataStore: Attempted to delete non-existent student with ID: \(id)")
                return false
            }

            print("DEBUG DataStore: Deleting student: \(student.fullName) with ID: \(id)")

            // Try to delete from database
            try dbManager.deleteStudent(id: id)

            // Remove from memory cache
            if let index = students.firstIndex(where: { $0.id == id }) {
                students.remove(at: index)
                print("DEBUG DataStore: Successfully deleted student from memory cache")
            }

            objectWillChange.send()
            return true
        } catch {
            print("ERROR DataStore: Failed to delete student: \(error.localizedDescription)")
            return false
        }
    }


    func getStudent(id: UUID) -> Student? {
        // First check memory cache
        if let cachedStudent = students.first(where: { $0.id == id }) {
            return cachedStudent
        }

        // If not in cache, try loading from database
        do {
            if let dbStudent = try dbManager.fetchStudent(id: id) {
                return dbStudent
            }
        } catch {
            print("ERROR DataStore: Fehler beim Laden des Schülers: \(error)")
        }

        return nil
    }

    // In DataStore.swift, verify the getStudentsForClass implementation:
    func getStudentsForClass(classId: UUID, includeArchived: Bool = false) -> [Student] {
        // Filter students from the in-memory array
        let filteredStudents = students.filter { student in
            student.classId == classId && (includeArchived || !student.isArchived)
        }

        print("DEBUG DataStore.getStudentsForClass: Found \(filteredStudents.count) students for class \(classId), includeArchived=\(includeArchived)")

        return filteredStudents.sorted { $0.sortableName < $1.sortableName }
    }

    func archiveStudent(_ student: Student) -> Bool {
        print("DEBUG DataStore: Archiving student: \(student.fullName) with ID: \(student.id)")
        var updatedStudent = student
        updatedStudent.isArchived = true
        return updateStudent(updatedStudent)
    }

    func isStudentNameUnique(firstName: String, lastName: String, classId: UUID, exceptStudentId: UUID? = nil) -> Bool {
        // Normalize names for comparison (trim whitespace, lowercase)
        let normalizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Filter students to find duplicates
        let duplicates = students.filter { student in
            // Skip the student we're checking against (for updates)
            if let exceptId = exceptStudentId, student.id == exceptId {
                return false
            }

            // Only check active students in the same class
            if student.classId != classId || student.isArchived {
                return false
            }

            // Normalize the student's name for comparison
            let studentFirstName = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let studentLastName = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Check for exact match
            return studentFirstName == normalizedFirstName && studentLastName == normalizedLastName
        }

        // If duplicates array is empty, the name is unique
        return duplicates.isEmpty
    }

    // MARK: - SeatingPosition Operations

        func loadSeatingPositions() {
            do {
                seatingPositions = try dbManager.fetchSeatingPositions()
                print("DEBUG DataStore: \(seatingPositions.count) seating positions loaded")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Error loading seating positions: \(error)")
                seatingPositions = []
            }
        }

        func addSeatingPosition(_ position: SeatingPosition) {
            do {
                let savedPosition = try dbManager.saveSeatingPosition(position)
                seatingPositions.append(savedPosition)
                print("DEBUG DataStore: Seating position added for student \(position.studentId)")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Error adding seating position: \(error)")
            }
        }

        func updateSeatingPosition(_ position: SeatingPosition) {
            do {
                let updatedPosition = try dbManager.saveSeatingPosition(position)

                if let index = seatingPositions.firstIndex(where: { $0.id == updatedPosition.id }) {
                    seatingPositions[index] = updatedPosition
                    print("DEBUG DataStore: Seating position updated")
                } else {
                    seatingPositions.append(updatedPosition)
                    print("DEBUG DataStore: Seating position added (update)")
                }

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Error updating seating position: \(error)")
            }
        }

        func deleteSeatingPosition(id: UUID) {
            do {
                try dbManager.deleteSeatingPosition(id: id)

                if let index = seatingPositions.firstIndex(where: { $0.id == id }) {
                    seatingPositions.remove(at: index)
                    print("DEBUG DataStore: Seating position deleted")
                }

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Error deleting seating position: \(error)")
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

        func getSeatingPositionForStudent(studentId: UUID, classId: UUID) -> SeatingPosition? {
            return seatingPositions.first { $0.studentId == studentId && $0.classId == classId }
        }

        // Helper method to arrange students in a grid
        func arrangeSeatingPositionsInGrid(classId: UUID, columns: Int) {
            // Get all students for this class
            let studentsInClass = getStudentsForClass(classId: classId)

            // Sort students by last name for consistent arrangement
            let sortedStudents = studentsInClass.sorted { $0.lastName < $1.lastName }

            // Arrange each student in a grid pattern
            for (index, student) in sortedStudents.enumerated() {
                let row = index / columns
                let col = index % columns

                // Check if a position already exists
                if let existingPosition = getSeatingPositionForStudent(studentId: student.id, classId: classId) {
                    var updatedPosition = existingPosition
                    updatedPosition.xPos = col
                    updatedPosition.yPos = row
                    updatedPosition.lastUpdated = Date()
                    updatedPosition.isCustomPosition = false

                    updateSeatingPosition(updatedPosition)
                } else {
                    // Create a new position
                    let newPosition = SeatingPosition(
                        studentId: student.id,
                        classId: classId,
                        xPos: col,
                        yPos: row,
                        lastUpdated: Date(),
                        isCustomPosition: false
                    )

                    addSeatingPosition(newPosition)
                }
            }

            print("DEBUG DataStore: Arranged \(sortedStudents.count) students in \(columns)-column grid")
        }


    // MARK: - Bewertungs-Operationen

        func loadRatings() {
            do {
                ratings = try dbManager.fetchRatings()
                print("DEBUG DataStore: \(ratings.count) Bewertungen geladen")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen: \(error)")
                ratings = []
            }
        }

        func addRating(_ rating: Rating) {
            do {
                // Sicherstellen, dass die Bewertung ein Schuljahr hat
                var ratingToSave = rating
                if ratingToSave.schoolYear.isEmpty {
                    ratingToSave.schoolYear = currentSchoolYear()
                }

                let savedRating = try dbManager.saveRating(ratingToSave)
                ratings.append(savedRating)
                print("DEBUG DataStore: Bewertung hinzugefügt")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Hinzufügen der Bewertung: \(error)")
            }
        }

        func updateRating(_ rating: Rating) {
            do {
                let updatedRating = try dbManager.saveRating(rating)

                if let index = ratings.firstIndex(where: { $0.id == updatedRating.id }) {
                    ratings[index] = updatedRating
                } else {
                    ratings.append(updatedRating)
                }

                print("DEBUG DataStore: Bewertung aktualisiert")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Aktualisieren der Bewertung: \(error)")
            }
        }

        func deleteRating(id: UUID) {
            do {
                try dbManager.deleteRating(id: id)

                if let index = ratings.firstIndex(where: { $0.id == id }) {
                    ratings.remove(at: index)
                    print("DEBUG DataStore: Bewertung gelöscht")
                }

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Löschen der Bewertung: \(error)")
            }
        }

        func getRating(id: UUID) -> Rating? {
            return ratings.first { $0.id == id }
        }

        func getRatingsForStudent(studentId: UUID) -> [Rating] {
            do {
                return try dbManager.fetchRatingsForStudent(studentId: studentId)
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen für Schüler: \(error)")
                return ratings.filter { $0.studentId == studentId && !$0.isArchived }
            }
        }

        func getRatingsForClass(classId: UUID, includeArchived: Bool = false) -> [Rating] {
            do {
                return try dbManager.fetchRatingsForClass(classId: classId, includeArchived: includeArchived)
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen für Klasse: \(error)")
                return ratings.filter {
                    $0.classId == classId && (includeArchived || !$0.isArchived)
                }
            }
        }

    // MARK: - Backup-Funktionen

        func createBackup() -> URL? {
            return BackupManager.shared.createBackup()
        }

        func restoreFromBackup(url: URL) -> Bool {
            let success = BackupManager.shared.restoreBackup(from: url)
            if success {
                loadAllData()
            }
            return success
        }

        func getAvailableBackups() -> [URL] {
            return BackupManager.shared.listAvailableBackups()
        }

        func deleteBackup(url: URL) -> Bool {
            return BackupManager.shared.deleteBackup(at: url)
        }

        // MARK: - Debug-Funktionen

        func resetAllData() {
            do {
                try AppDatabase.shared.write { db in
                    try Class.deleteAll(db)
                    try Student.deleteAll(db)
                    try SeatingPosition.deleteAll(db)
                    try Rating.deleteAll(db)
                }

                // In-Memory-Listen zurücksetzen
                classes = []
                students = []
                seatingPositions = []
                ratings = []

                print("DEBUG DataStore: Alle Daten zurückgesetzt")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Zurücksetzen aller Daten: \(error)")
            }
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

            // Beispielschüler hinzufügen
            if !classes.isEmpty {
                for classObj in classes {
                    addSampleStudentsToClass(classId: classObj.id)
                }
            }
        }

    private func addSampleStudentsToClass(classId: UUID, count: Int = 40) {
        // Erweiterte Listen von Vor- und Nachnamen für mehr Variation
        let firstNames = ["Max", "Anna", "Paul", "Sophie", "Tom", "Lisa", "Felix", "Sarah", "Lukas", "Lena",
                          "Jonas", "Laura", "David", "Julia", "Niklas", "Emma", "Alexander", "Mia", "Leon", "Hannah",
                          "Finn", "Marie", "Elias", "Emilia", "Noah", "Charlotte", "Ben", "Lina", "Luis", "Lea",
                          "Henry", "Johanna", "Theo", "Ida", "Samuel", "Clara", "Oscar", "Mathilda", "Anton", "Ella",
                          "Emil", "Helena", "Jakob", "Victoria", "Jonathan", "Greta", "Moritz", "Amelie", "Vincent", "Zoe"]

        let lastNames = ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Hoffmann", "Schulz",
                         "Bauer", "Koch", "Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann", "Braun",
                         "Krüger", "Hofmann", "Hartmann", "Lange", "Schmitt", "Werner", "Schmitz", "Krause", "Meier", "Lehmann",
                         "Schmid", "Schulze", "Maier", "Köhler", "Herrmann", "Walter", "König", "Mayer", "Huber", "Kaiser",
                         "Fuchs", "Peters", "Lang", "Scholz", "Möller", "Weiß", "Jung", "Hahn", "Schubert", "Vogel"]

        // Ein Set, um die bereits verwendeten Namenskombinationen zu speichern
        var usedNames = Set<String>()
        var studentsAdded = 0

        // Mehr Durchläufe als nötig, um für Ausfälle durch Duplikate zu kompensieren
        for _ in 0..<(count * 2) {
            // Wenn wir bereits die gewünschte Anzahl erreicht haben, brechen wir ab
            if studentsAdded >= count {
                break
            }

            // Zufälligen Vor- und Nachnamen generieren
            let firstName = firstNames[Int.random(in: 0..<firstNames.count)]
            let lastName = lastNames[Int.random(in: 0..<lastNames.count)]

            // Prüfen, ob diese Kombination bereits verwendet wurde
            let nameKey = "\(firstName)|\(lastName)"
            if usedNames.contains(nameKey) {
                continue  // Falls duplikat, überspringen und nächsten Versuch machen
            }

            // Namen als verwendet markieren
            usedNames.insert(nameKey)

            // Gelegentlich Notizen hinzufügen
            let note = Int.random(in: 0...5) == 0 ? "Sprachförderung" : nil

            let student = Student(
                firstName: firstName,
                lastName: lastName,
                classId: classId,
                notes: note
            )

            // Versuchen, den Schüler hinzuzufügen
            do {
                try student.validate()  // Validieren vor dem Hinzufügen

                // Prüfen, ob der Name in der Klasse einzigartig ist
                if !isStudentNameUnique(firstName: firstName, lastName: lastName, classId: classId) {
                    continue  // Falls nicht einzigartig, überspringen
                }

                addStudent(student)
                studentsAdded += 1

                // Sitzposition hinzufügen
                let xPos = Int.random(in: 0...5)
                let yPos = Int.random(in: 0...5)

                let position = SeatingPosition(
                    studentId: student.id,
                    classId: classId,
                    xPos: xPos,
                    yPos: yPos
                )

                addSeatingPosition(position)
            } catch {
                // Bei Fehler einfach weitermachen und nächsten Versuch starten
                continue
            }
        }

        print("DEBUG DataStore: \(studentsAdded) Beispielschüler zur Klasse hinzugefügt")
    }


    // Add to DataStore.swift

    // Method for testing purposes
    func resetForTesting(with dbQueue: DatabaseQueue) {
        // Reset all cached data
        classes = []
        students = []
        seatingPositions = []
        ratings = []

        // Inject the test database connection
        // This would ideally be done by making the dbManager a property that can be replaced,
        // but as a temporary solution for testing we can create a specific testing method
        do {
            try GRDBManager.shared.migrateAllDataFromUserDefaults()
        } catch {
            print("Error setting up test database: \(error)")
        }
    }


    }

