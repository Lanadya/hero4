import Foundation
import Combine
import GRDB

class DataStore: ObservableObject {
    static let shared = DataStore()

    // Veröffentlichte Eigenschaften für SwiftUI-Binding
    @Published var classes: [Class] = []
    @Published var students: [Student] = []
    @Published var seatingPositions: [SeatingPosition] = []
    @Published var absenceStatuses: [UUID: Bool] = [:]
    @Published var ratings: [Rating] = []

    // UserDefaults-Schlüssel als Fallback
    private let classesKey = "hero4_classes"
    private let studentsKey = "hero4_students"
    private let seatingPositionsKey = "hero4_seating_positions"
    private let absenceStatusesKey = "hero4_absence_statuses"
    private let ratingsKey = "hero4_ratings"

    // Referenz zum GRDBManager
    private let dbManager = GRDBManager.shared

    // Backup-Manager für Sicherungen
    private let backupManager = BackupManager.shared

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

    // MARK: - Klassen-Operationen

    func loadClasses() {
        do {
            // Versuche, Klassen aus der Datenbank zu laden
            classes = try dbManager.fetchClasses()
            print("DEBUG DataStore: \(classes.count) Klassen aus Datenbank geladen")

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Klassen aus der Datenbank: \(error)")

            // Fallback zu UserDefaults, falls Datenbankzugriff fehlschlägt
            if let data = UserDefaults.standard.data(forKey: classesKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    classes = try decoder.decode([Class].self, from: data)
                    print("DEBUG DataStore: Klassen aus UserDefaults geladen: \(classes.count)")
                } catch {
                    print("FEHLER DataStore: Fehler beim Laden der Klassen aus UserDefaults: \(error)")
                    classes = []
                }
            } else {
                print("DEBUG DataStore: Keine gespeicherten Klassen gefunden.")
                classes = []
            }

            objectWillChange.send()
        }
    }

    func addClass(_ class: Class) {
        do {
            // Klasse in Datenbank speichern
            let savedClass = try dbManager.saveClass(`class`)

            // In-Memory-Liste aktualisieren
            classes.append(savedClass)

            print("DEBUG DataStore: Klasse \(savedClass.name) zur Datenbank hinzugefügt")
            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Hinzufügen der Klasse zur Datenbank: \(error)")

            // Fallback zu UserDefaults
            classes.append(`class`)
            saveClassesToUserDefaults()
        }
    }

    func updateClass(_ class: Class) {
        do {
            // Klasse in Datenbank aktualisieren
            let updatedClass = try dbManager.saveClass(`class`)

            // In-Memory-Liste aktualisieren
            if let index = classes.firstIndex(where: { $0.id == updatedClass.id }) {
                classes[index] = updatedClass
                print("DEBUG DataStore: Klasse \(updatedClass.name) in Datenbank aktualisiert")
            } else {
                classes.append(updatedClass)
                print("DEBUG DataStore: Klasse \(updatedClass.name) zur Datenbank hinzugefügt (Update)")
            }

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Aktualisieren der Klasse in der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = classes.firstIndex(where: { $0.id == `class`.id }) {
                classes[index] = `class`
                saveClassesToUserDefaults()
            }
        }
    }

    func deleteClass(id: UUID) {
        do {
            // Klasse aus Datenbank löschen
            try dbManager.deleteClass(id: id)

            // Aus In-Memory-Liste entfernen
            if let index = classes.firstIndex(where: { $0.id == id }) {
                let classToDelete = classes[index]
                classes.remove(at: index)
                print("DEBUG DataStore: Klasse \(classToDelete.name) aus Datenbank gelöscht")
            }

            // Zugehörige Daten löschen
            deleteStudentsForClass(classId: id)
            deleteSeatingPositionsForClass(classId: id)
            deleteRatingsForClass(classId: id)

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Löschen der Klasse aus der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = classes.firstIndex(where: { $0.id == id }) {
                classes.remove(at: index)
                saveClassesToUserDefaults()

                // Zugehörige Daten löschen (UserDefaults-Methoden)
                deleteStudentsForClass(classId: id)
                deleteSeatingPositionsForClass(classId: id)
            }
        }
    }

    func getClass(id: UUID) -> Class? {
        // Zuerst in Memory-Cache nachsehen
        if let cachedClass = classes.first(where: { $0.id == id }) {
            return cachedClass
        }

        // Falls nicht gefunden, aus Datenbank laden
        do {
            if let dbClass = try dbManager.fetchClass(id: id) {
                // Zum Cache hinzufügen
                if !classes.contains(where: { $0.id == id }) {
                    classes.append(dbClass)
                }
                return dbClass
            }
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Klasse aus der Datenbank: \(error)")
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
            print("DEBUG DataStore: Klasse an Position (\(row), \(column)) im Cache gefunden: \(foundClass.name)")
            return foundClass
        }

        // Falls nicht im Cache, aus der Datenbank laden
        do {
            if let dbClass = try dbManager.fetchClassAt(row: row, column: column) {
                print("DEBUG DataStore: Klasse an Position (\(row), \(column)) in der Datenbank gefunden: \(dbClass.name)")
                return dbClass
            }
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Klasse aus der Datenbank: \(error)")
        }

        print("DEBUG DataStore: Keine Klasse an Position (\(row), \(column)) gefunden")
        return nil
    }

    func archiveClass(_ class: Class) {
        var updatedClass = `class`
        updatedClass.isArchived = true
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

    func isClassNameUnique(_ name: String, exceptClassId: UUID? = nil) -> Bool {
        let matchingClasses = classes.filter {
            !$0.isArchived &&
            $0.name.lowercased() == name.lowercased() &&
            $0.id != exceptClassId
        }

        return matchingClasses.isEmpty
    }

    func findSimilarClassNames(_ name: String, exceptClassId: UUID? = nil) -> [String] {
        let lowercaseName = name.lowercased()

        return classes.filter {
            !$0.isArchived &&
            $0.name.lowercased().contains(lowercaseName) &&
            $0.id != exceptClassId
        }.map { $0.name }
    }

    // MARK: - Schüler-Operationen

    func loadStudents() {
        do {
            // Versuche, Schüler aus der Datenbank zu laden
            students = try dbManager.fetchStudents()
            print("DEBUG DataStore: \(students.count) Schüler aus Datenbank geladen")

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Schüler aus der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let data = UserDefaults.standard.data(forKey: studentsKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    students = try decoder.decode([Student].self, from: data)
                    print("DEBUG DataStore: Schüler aus UserDefaults geladen: \(students.count)")
                } catch {
                    print("FEHLER DataStore: Fehler beim Laden der Schüler aus UserDefaults: \(error)")
                    students = []
                }
            } else {
                print("DEBUG DataStore: Keine gespeicherten Schüler gefunden.")
                students = []
            }

            objectWillChange.send()
        }
    }

    func addStudent(_ student: Student) {
        do {
            // Validieren und prüfen, ob Name eindeutig ist
            try student.validate()

            if !isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: student.classId) {
                print("FEHLER DataStore: Schüler mit Namen '\(student.firstName) \(student.lastName)' existiert bereits in dieser Klasse.")
                return
            }

            // Schüler in Datenbank speichern
            let savedStudent = try dbManager.saveStudent(student)

            // In-Memory-Liste aktualisieren
            students.append(savedStudent)

            print("DEBUG DataStore: Schüler \(savedStudent.fullName) zur Datenbank hinzugefügt")
            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Hinzufügen des Schülers zur Datenbank: \(error)")

            // Fallback zu UserDefaults
            students.append(student)
            saveStudentsToUserDefaults()
        }
    }

    func updateStudent(_ student: Student) {
        do {
            // Validieren
            try student.validate()

            // Schüler in Datenbank aktualisieren
            let updatedStudent = try dbManager.saveStudent(student)

            // In-Memory-Liste aktualisieren
            if let index = students.firstIndex(where: { $0.id == updatedStudent.id }) {
                students[index] = updatedStudent
                print("DEBUG DataStore: Schüler \(updatedStudent.fullName) in Datenbank aktualisiert")
            } else {
                students.append(updatedStudent)
                print("DEBUG DataStore: Schüler \(updatedStudent.fullName) zur Datenbank hinzugefügt (Update)")
            }

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Aktualisieren des Schülers in der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = students.firstIndex(where: { $0.id == student.id }) {
                students[index] = student
                saveStudentsToUserDefaults()
            }
        }
    }

    func deleteStudent(id: UUID) {
        do {
            // Schüler aus Datenbank löschen
            try dbManager.deleteStudent(id: id)

            // Aus In-Memory-Liste entfernen
            if let index = students.firstIndex(where: { $0.id == id }) {
                print("DEBUG DataStore: Schüler \(students[index].fullName) aus Datenbank gelöscht")
                students.remove(at: index)
            }

            // Zugehörige Daten löschen
            deleteSeatingPositionsForStudent(studentId: id)
            deleteRatingsForStudent(studentId: id)
            absenceStatuses.removeValue(forKey: id)

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Löschen des Schülers aus der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = students.firstIndex(where: { $0.id == id }) {
                students.remove(at: index)
                saveStudentsToUserDefaults()

                // Zugehörige Daten löschen
                seatingPositions.removeAll(where: { $0.studentId == id })
                saveSeatingPositionsToUserDefaults()

                absenceStatuses.removeValue(forKey: id)
                saveAbsenceStatusesToUserDefaults()

                ratings.removeAll(where: { $0.studentId == id })
                saveRatingsToUserDefaults()
            }
        }
    }

    func deleteStudentsForClass(classId: UUID) {
        // Schüler für diese Klasse identifizieren
        let studentsToDelete = students.filter { $0.classId == classId }

        // Jeden Schüler einzeln löschen (um alle zugehörigen Daten zu bereinigen)
        for student in studentsToDelete {
            deleteStudent(id: student.id)
        }

        print("DEBUG DataStore: \(studentsToDelete.count) Schüler der Klasse mit ID \(classId) gelöscht.")
    }

    func getStudent(id: UUID) -> Student? {
        // Zuerst in Memory-Cache nachsehen
        if let cachedStudent = students.first(where: { $0.id == id }) {
            return cachedStudent
        }

        // Falls nicht gefunden, aus Datenbank laden
        do {
            if let dbStudent = try dbManager.fetchStudent(id: id) {
                // Zum Cache hinzufügen
                if !students.contains(where: { $0.id == id }) {
                    students.append(dbStudent)
                }
                return dbStudent
            }
        } catch {
            print("ERROR DataStore: Fehler beim Laden des Schülers aus der Datenbank: \(error)")
        }

        return nil
    }

    func getStudentsForClass(classId: UUID, includeArchived: Bool = false) -> [Student] {
        do {
            // Schüler für die Klasse aus der Datenbank laden
            let classStudents = try dbManager.fetchStudentsForClass(classId: classId, includeArchived: includeArchived)

            // Cache aktualisieren
            for student in classStudents {
                if !students.contains(where: { $0.id == student.id }) {
                    students.append(student)
                }
            }

            // Sortierte Liste zurückgeben
            return classStudents.sorted { $0.sortableName < $1.sortableName }
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Schüler für Klasse aus der Datenbank: \(error)")

            // Fallback: aus dem Memory-Cache filtern
            return students.filter {
                $0.classId == classId && (includeArchived || !$0.isArchived)
            }.sorted { $0.sortableName < $1.sortableName }
        }
    }

    func archiveStudent(_ student: Student) {
        var updatedStudent = student
        updatedStudent.isArchived = true
        updateStudent(updatedStudent)
    }

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

    // MARK: - Abwesenheitsstatus-Operationen

    func loadAbsenceStatuses() {
        // Da Abwesenheitsstatus kein separates Datenbankmodell ist, wird es weiterhin in UserDefaults gespeichert
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

    func updateStudentAbsenceStatus(studentId: UUID, isAbsent: Bool) {
        absenceStatuses[studentId] = isAbsent
        saveAbsenceStatusesToUserDefaults()
        print("DEBUG DataStore: Abwesenheitsstatus für Schüler \(studentId) auf \(isAbsent) gesetzt")
    }

    func isStudentAbsent(_ studentId: UUID) -> Bool {
        return absenceStatuses[studentId] ?? false
    }

    // MARK: - Sitzpositionen-Operationen

    func loadSeatingPositions() {
        do {
            // Versuche, Sitzpositionen aus der Datenbank zu laden
            seatingPositions = try dbManager.fetchSeatingPositions()
            print("DEBUG DataStore: \(seatingPositions.count) Sitzpositionen aus Datenbank geladen")

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Sitzpositionen aus der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let data = UserDefaults.standard.data(forKey: seatingPositionsKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    seatingPositions = try decoder.decode([SeatingPosition].self, from: data)
                    print("DEBUG DataStore: Sitzpositionen aus UserDefaults geladen: \(seatingPositions.count)")
                } catch {
                    print("FEHLER DataStore: Fehler beim Laden der Sitzpositionen aus UserDefaults: \(error)")
                    seatingPositions = []
                }
            } else {
                print("DEBUG DataStore: Keine gespeicherten Sitzpositionen gefunden.")
                seatingPositions = []
            }

            objectWillChange.send()
        }
    }

    func addSeatingPosition(_ position: SeatingPosition) {
        do {
            // Sitzposition in Datenbank speichern
            let savedPosition = try dbManager.saveSeatingPosition(position)

            // In-Memory-Liste aktualisieren
            if let existingIndex = seatingPositions.firstIndex(where: {
                $0.studentId == position.studentId && $0.classId == position.classId
            }) {
                // Bestehende Position aktualisieren
                seatingPositions[existingIndex] = savedPosition
                print("DEBUG DataStore: Bestehende Sitzposition in Datenbank aktualisiert.")
            } else {
                // Neue Position hinzufügen
                seatingPositions.append(savedPosition)
                print("DEBUG DataStore: Neue Sitzposition zur Datenbank hinzugefügt.")
            }

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Speichern der Sitzposition in der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let existingIndex = seatingPositions.firstIndex(where: {
                $0.studentId == position.studentId && $0.classId == position.classId
            }) {
                seatingPositions[existingIndex] = position
            } else {
                seatingPositions.append(position)
            }
            saveSeatingPositionsToUserDefaults()
        }
    }

    func updateSeatingPosition(_ position: SeatingPosition) {
        do {
            // Sitzposition in Datenbank aktualisieren
            let updatedPosition = try dbManager.saveSeatingPosition(position)

            // In-Memory-Liste aktualisieren
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions[index] = updatedPosition
                print("DEBUG DataStore: Sitzposition in Datenbank aktualisiert.")
            } else {
                seatingPositions.append(updatedPosition)
                print("DEBUG DataStore: Neue Sitzposition zur Datenbank hinzugefügt (Update).")
            }

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Aktualisieren der Sitzposition in der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions[index] = position
                saveSeatingPositionsToUserDefaults()
            }
        }
    }

    func deleteSeatingPosition(id: UUID) {
        do {
            // Sitzposition aus Datenbank löschen
            try dbManager.deleteSeatingPosition(id: id)

            // Aus In-Memory-Liste entfernen
            if let index = seatingPositions.firstIndex(where: { $0.id == id }) {
                seatingPositions.remove(at: index)
                print("DEBUG DataStore: Sitzposition aus Datenbank gelöscht.")
            }

            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Löschen der Sitzposition aus der Datenbank: \(error)")

            // Fallback zu UserDefaults
            if let index = seatingPositions.firstIndex(where: { $0.id == id }) {
                seatingPositions.remove(at: index)
                saveSeatingPositionsToUserDefaults()
            }
        }
    }

    func deleteSeatingPositionsForStudent(studentId: UUID) {
        // Alle Positionen für diesen Schüler identifizieren
        let positionsToDelete = seatingPositions.filter { $0.studentId == studentId }

        // Alle Positionen löschen
        for position in positionsToDelete {
            deleteSeatingPosition(id: position.id)
        }

        if !positionsToDelete.isEmpty {
            print("DEBUG DataStore: \(positionsToDelete.count) Sitzpositionen für Schüler mit ID \(studentId) gelöscht.")
        }
    }

    func deleteSeatingPositionsForClass(classId: UUID) {
        // Alle Positionen für diese Klasse identifizieren
        let positionsToDelete = seatingPositions.filter { $0.classId == classId }

        // Alle Positionen löschen
        for position in positionsToDelete {
            deleteSeatingPosition(id: position.id)
        }

        if !positionsToDelete.isEmpty {
            print("DEBUG DataStore: \(positionsToDelete.count) Sitzpositionen für Klasse mit ID \(classId) gelöscht.")
        }
    }

    func getSeatingPosition(studentId: UUID, classId: UUID) -> SeatingPosition? {
        // Zuerst in Memory-Cache nachsehen
        if let cachedPosition = seatingPositions.first(where: {
            $0.studentId == studentId && $0.classId == classId
        }) {
            return cachedPosition
        }

        // Falls nicht gefunden, aus Datenbank laden
        do {
            if let dbPosition = try dbManager.fetchSeatingPositionForStudent(studentId: studentId, classId: classId) {
                // Zum Cache hinzufügen
                if !seatingPositions.contains(where: { $0.id == dbPosition.id }) {
                    seatingPositions.append(dbPosition)
                }
                return dbPosition
            }
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Sitzposition aus der Datenbank: \(error)")
        }

        return nil
    }

    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition] {
        do {
            // Sitzpositionen für die Klasse aus der Datenbank laden
            let classPositions = try dbManager.fetchSeatingPositionsForClass(classId: classId)

            // Cache aktualisieren
            for position in classPositions {
                if !seatingPositions.contains(where: { $0.id == position.id }) {
                    seatingPositions.append(position)
                }
            }

            return classPositions
        } catch {
            print("ERROR DataStore: Fehler beim Laden der Sitzpositionen für Klasse aus der Datenbank: \(error)")

            // Fallback: aus dem Memory-Cache filtern
            return seatingPositions.filter { $0.classId == classId }
        }
    }

    func updateSeatingPositionsInBatch(_ positions: [SeatingPosition]) {
        do {
            // Alle Positionen in einer Transaktion aktualisieren
            try AppDatabase.shared.write { db in
                for position in positions {
                    try position.save(db)
                }
            }

            // Memory-Cache aktualisieren
            for position in positions {
                if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                    seatingPositions[index] = position
                } else {
                    seatingPositions.append(position)
                }
            }

            print("DEBUG DataStore: \(positions.count) Sitzpositionen in der Datenbank aktualisiert.")
            objectWillChange.send()
        } catch {
            print("ERROR DataStore: Fehler beim Batch-Update der Sitzpositionen in der Datenbank: \(error)")

            // Fallback zu UserDefaults
            for position in positions {
                if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                    seatingPositions[index] = position
                } else {
                    seatingPositions.append(position)
                }
            }
            saveSeatingPositionsToUserDefaults()
        }
    }

    func resetSeatingPositionsForClass(classId: UUID) {
        // Alle Positionen für diese Klasse löschen
        deleteSeatingPositionsForClass(classId: classId)

        print("DEBUG DataStore: Alle Sitzpositionen für Klasse mit ID \(classId) zurückgesetzt.")
    }

    func arrangeSeatingPositionsInGrid(classId: UUID, columns: Int) {
        // Bestehende Positionen löschen
        resetSeatingPositionsForClass(classId: classId)

        // Schüler für diese Klasse laden
        let studentsForClass = getStudentsForClass(classId: classId)

        // Neue Positionen in einem Raster erstellen
        var newPositions: [SeatingPosition] = []

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

            newPositions.append(position)
        }

        // Alle neuen Positionen in einem Rutsch speichern
        updateSeatingPositionsInBatch(newPositions)

        print("DEBUG DataStore: \(newPositions.count) Schüler in einem \(columns)-spaltigen Raster angeordnet.")
    }

    // MARK: - Bewertungen-Operationen

    func loadRatings() {
            do {
                // Versuche, Bewertungen aus der Datenbank zu laden
                ratings = try dbManager.fetchRatings()
                print("DEBUG DataStore: \(ratings.count) Bewertungen aus Datenbank geladen")

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen aus der Datenbank: \(error)")

                // Fallback zu UserDefaults
                if let data = UserDefaults.standard.data(forKey: ratingsKey) {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        ratings = try decoder.decode([Rating].self, from: data)
                        print("DEBUG DataStore: Bewertungen aus UserDefaults geladen: \(ratings.count)")
                    } catch {
                        print("FEHLER DataStore: Fehler beim Laden der Bewertungen aus UserDefaults: \(error)")
                        ratings = []
                    }
                } else {
                    print("DEBUG DataStore: Keine gespeicherten Bewertungen gefunden.")
                    ratings = []
                }

                objectWillChange.send()
            }
        }

        func addRating(_ rating: Rating) {
            do {
                // Bewertung in Datenbank speichern
                var newRating = rating
                if newRating.schoolYear.isEmpty {
                    newRating.schoolYear = currentSchoolYear()
                }

                let savedRating = try dbManager.saveRating(newRating)

                // In-Memory-Liste aktualisieren
                ratings.append(savedRating)

                print("DEBUG DataStore: Neue Bewertung für Schüler \(savedRating.studentId) zur Datenbank hinzugefügt")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Hinzufügen der Bewertung zur Datenbank: \(error)")

                // Fallback zu UserDefaults
                var newRating = rating
                if newRating.schoolYear.isEmpty {
                    newRating.schoolYear = currentSchoolYear()
                }
                ratings.append(newRating)
                saveRatingsToUserDefaults()
            }
        }

        func updateRating(_ rating: Rating) {
            do {
                // Bewertung in Datenbank aktualisieren
                let updatedRating = try dbManager.saveRating(rating)

                // In-Memory-Liste aktualisieren
                if let index = ratings.firstIndex(where: { $0.id == updatedRating.id }) {
                    ratings[index] = updatedRating
                    print("DEBUG DataStore: Bewertung in Datenbank aktualisiert.")
                } else {
                    ratings.append(updatedRating)
                    print("DEBUG DataStore: Neue Bewertung zur Datenbank hinzugefügt (Update).")
                }

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Aktualisieren der Bewertung in der Datenbank: \(error)")

                // Fallback zu UserDefaults
                if let index = ratings.firstIndex(where: { $0.id == rating.id }) {
                    ratings[index] = rating
                    saveRatingsToUserDefaults()
                }
            }
        }

        func deleteRating(id: UUID) {
            do {
                // Bewertung aus Datenbank löschen
                try dbManager.deleteRating(id: id)

                // Aus In-Memory-Liste entfernen
                if let index = ratings.firstIndex(where: { $0.id == id }) {
                    ratings.remove(at: index)
                    print("DEBUG DataStore: Bewertung aus Datenbank gelöscht.")
                }

                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Löschen der Bewertung aus der Datenbank: \(error)")

                // Fallback zu UserDefaults
                if let index = ratings.firstIndex(where: { $0.id == id }) {
                    ratings.remove(at: index)
                    saveRatingsToUserDefaults()
                }
            }
        }

        func deleteRatingsForStudent(studentId: UUID) {
            // Alle Bewertungen für diesen Schüler identifizieren
            let ratingsToDelete = ratings.filter { $0.studentId == studentId }

            // Alle Bewertungen löschen
            for rating in ratingsToDelete {
                deleteRating(id: rating.id)
            }

            if !ratingsToDelete.isEmpty {
                print("DEBUG DataStore: \(ratingsToDelete.count) Bewertungen für Schüler mit ID \(studentId) gelöscht.")
            }
        }

        func deleteRatingsForClass(classId: UUID) {
            // Alle Bewertungen für diese Klasse identifizieren
            let ratingsToDelete = ratings.filter { $0.classId == classId }

            // Alle Bewertungen löschen
            for rating in ratingsToDelete {
                deleteRating(id: rating.id)
            }

            if !ratingsToDelete.isEmpty {
                print("DEBUG DataStore: \(ratingsToDelete.count) Bewertungen für Klasse mit ID \(classId) gelöscht.")
            }
        }

        func getRating(id: UUID) -> Rating? {
            // Zuerst in Memory-Cache nachsehen
            if let cachedRating = ratings.first(where: { $0.id == id }) {
                return cachedRating
            }

            // Falls nicht gefunden, aus Datenbank laden
            do {
                if let dbRating = try dbManager.fetchRating(id: id) {
                    // Zum Cache hinzufügen
                    if !ratings.contains(where: { $0.id == id }) {
                        ratings.append(dbRating)
                    }
                    return dbRating
                }
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertung aus der Datenbank: \(error)")
            }

            return nil
        }

        func getRatingsForStudent(studentId: UUID) -> [Rating] {
            do {
                // Bewertungen für den Schüler aus der Datenbank laden
                let studentRatings = try dbManager.fetchRatingsForStudent(studentId: studentId)

                // Cache aktualisieren
                for rating in studentRatings {
                    if !ratings.contains(where: { $0.id == rating.id }) {
                        ratings.append(rating)
                    }
                }

                return studentRatings
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen für Schüler aus der Datenbank: \(error)")

                // Fallback: aus dem Memory-Cache filtern
                return ratings.filter { $0.studentId == studentId && !$0.isArchived }
            }
        }

        func getRatingsForClass(classId: UUID, includeArchived: Bool = false) -> [Rating] {
            do {
                // Bewertungen für die Klasse aus der Datenbank laden
                let classRatings = try dbManager.fetchRatingsForClass(classId: classId, includeArchived: includeArchived)

                // Cache aktualisieren
                for rating in classRatings {
                    if !ratings.contains(where: { $0.id == rating.id }) {
                        ratings.append(rating)
                    }
                }

                return classRatings
            } catch {
                print("ERROR DataStore: Fehler beim Laden der Bewertungen für Klasse aus der Datenbank: \(error)")

                // Fallback: aus dem Memory-Cache filtern
                return ratings.filter {
                    $0.classId == classId && (includeArchived || !$0.isArchived)
                }
            }
        }

        // MARK: - Backup/Restore Funktionen

        func createBackup() -> URL? {
            // Erstelle ein Backup der Datenbank
            let backupURL = backupManager.createBackup()

            if backupURL != nil {
                print("DEBUG DataStore: Backup erstellt unter: \(backupURL!.path)")
            } else {
                print("FEHLER DataStore: Backup konnte nicht erstellt werden")
            }

            return backupURL
        }

        func restoreFromBackup(url: URL) -> Bool {
            // Stelle ein Backup wieder her
            let success = backupManager.restoreBackup(from: url)

            if success {
                print("DEBUG DataStore: Backup wiederhergestellt von: \(url.path)")

                // Daten neu laden
                loadAllData()
            } else {
                print("FEHLER DataStore: Backup konnte nicht wiederhergestellt werden")
            }

            return success
        }

        func getAvailableBackups() -> [URL] {
            // Liste alle verfügbaren Backups auf
            return backupManager.listAvailableBackups()
        }

        func deleteBackup(url: URL) -> Bool {
            // Lösche ein Backup
            return backupManager.deleteBackup(at: url)
        }

        // MARK: - Debug-Funktionen

        func resetAllData() {
            // Alle Daten in der Datenbank löschen
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
                absenceStatuses = [:]

                // UserDefaults ebenfalls zurücksetzen
                UserDefaults.standard.removeObject(forKey: classesKey)
                UserDefaults.standard.removeObject(forKey: studentsKey)
                UserDefaults.standard.removeObject(forKey: seatingPositionsKey)
                UserDefaults.standard.removeObject(forKey: absenceStatusesKey)
                UserDefaults.standard.removeObject(forKey: ratingsKey)

                print("DEBUG DataStore: Alle Daten zurückgesetzt.")
                objectWillChange.send()
            } catch {
                print("ERROR DataStore: Fehler beim Zurücksetzen aller Daten: \(error)")

                // Fallback zu UserDefaults
                classes = []
                students = []
                seatingPositions = []
                ratings = []
                absenceStatuses = [:]

                saveClassesToUserDefaults()
                saveStudentsToUserDefaults()
                saveSeatingPositionsToUserDefaults()
                saveRatingsToUserDefaults()
                saveAbsenceStatusesToUserDefaults()
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

        // MARK: - Private UserDefaults Fallback-Funktionen

        private func saveClassesToUserDefaults() {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted

                let data = try encoder.encode(classes)
                UserDefaults.standard.set(data, forKey: classesKey)
                UserDefaults.standard.synchronize()

                print("DEBUG DataStore: Klassen in UserDefaults gespeichert: \(classes.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Speichern der Klassen in UserDefaults: \(error)")
            }
        }

        private func saveStudentsToUserDefaults() {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(students)
                UserDefaults.standard.set(data, forKey: studentsKey)
                UserDefaults.standard.synchronize()

                print("DEBUG DataStore: Schüler in UserDefaults gespeichert: \(students.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Speichern der Schüler in UserDefaults: \(error)")
            }
        }

        private func saveSeatingPositionsToUserDefaults() {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(seatingPositions)
                UserDefaults.standard.set(data, forKey: seatingPositionsKey)
                UserDefaults.standard.synchronize()

                print("DEBUG DataStore: Sitzpositionen in UserDefaults gespeichert: \(seatingPositions.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Speichern der Sitzpositionen in UserDefaults: \(error)")
            }
        }

        private func saveAbsenceStatusesToUserDefaults() {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(absenceStatuses)
                UserDefaults.standard.set(data, forKey: absenceStatusesKey)
                UserDefaults.standard.synchronize()

                print("DEBUG DataStore: Abwesenheitsstatus in UserDefaults gespeichert: \(absenceStatuses.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Speichern der Abwesenheitsstatus in UserDefaults: \(error)")
            }
        }

        private func saveRatingsToUserDefaults() {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(ratings)
                UserDefaults.standard.set(data, forKey: ratingsKey)
                UserDefaults.standard.synchronize()

                print("DEBUG DataStore: Bewertungen in UserDefaults gespeichert: \(ratings.count)")
            } catch {
                print("FEHLER DataStore: Fehler beim Speichern der Bewertungen in UserDefaults: \(error)")
            }
        }
    }
