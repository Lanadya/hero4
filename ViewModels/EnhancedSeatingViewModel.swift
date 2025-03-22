import Foundation
import Combine

class EnhancedSeatingViewModel: ObservableObject {
    // Veröffentlichte Variablen für die View
    @Published var students: [Student] = []
    @Published var classes: [Class] = []
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var seatingPositions: [SeatingPosition] = []
    @Published var absentStudents: Set<UUID> = [] // Neue Variable für abwesende Schüler
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // DataStore-Referenz
    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Beobachte Änderungen im DataStore
        setupObservers()
    }

    // MARK: - Datenbeobachtung

    private func setupObservers() {
        // Beobachte Änderungen bei den Klassen
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] classes in
                self?.classes = classes.filter { !$0.isArchived }
                self?.updateSelectedClass()
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Schülern
        dataStore.$students
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadStudentsForSelectedClass()
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Sitzpositionen
        dataStore.$seatingPositions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadSeatingPositionsForSelectedClass()
            }
            .store(in: &cancellables)
    }

    // MARK: - Klassen-Operationen

    func loadClasses() {
        print("DEBUG: Lade Klassen")
        dataStore.loadClasses()
    }

    func selectClass(_ id: UUID?) {
        print("DEBUG: Klasse auswählen: \(id?.uuidString ?? "keine")")
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()
        loadSeatingPositionsForSelectedClass()
        // Abwesenheitsstatus zurücksetzen bei Klassenwechsel
        absentStudents.removeAll()
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

    private func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            return
        }

        students = dataStore.getStudentsForClass(classId: classId)
        print("DEBUG: \(students.count) Schüler für Klasse geladen")
    }


    // Abwesenheitsstatus verwalten
    func updateStudentAbsenceStatus(studentId: UUID, isAbsent: Bool) {
        dataStore.updateStudentAbsenceStatus(studentId: studentId, isAbsent: isAbsent)
    }

    func isStudentAbsent(_ studentId: UUID) -> Bool {
        return dataStore.isStudentAbsent(studentId)
    }

    // Neue Methode: Notizen aktualisieren
    func updateStudentNotes(studentId: UUID, notes: String) {
        if let index = students.firstIndex(where: { $0.id == studentId }) {
            var updatedStudent = students[index]
            updatedStudent.notes = notes.isEmpty ? nil : notes

            // Schüler in der Datenbank aktualisieren
            dataStore.updateStudent(updatedStudent)

            print("DEBUG: Notizen für Schüler \(studentId) aktualisiert")
        }
    }

    // MARK: - Sitzposition-Operationen

    private func loadSeatingPositionsForSelectedClass() {
        guard let classId = selectedClassId else {
            seatingPositions = []
            return
        }

        // Bestehende Positionen laden
        seatingPositions = dataStore.getSeatingPositionsForClass(classId: classId)
        print("DEBUG: \(seatingPositions.count) Sitzpositionen geladen")

        // Für Schüler ohne Position eine Standardposition erstellen
        for student in students {
            if !seatingPositions.contains(where: { $0.studentId == student.id }) {
                // Erstelle eine Standardposition
                let defaultPosition = createDefaultPosition(for: student.id, classId: classId)
                seatingPositions.append(defaultPosition)
                dataStore.addSeatingPosition(defaultPosition)
            }
        }
    }

    // MARK: - Öffentliche Zugriffsmethoden

    /// Lädt die Sitzpositionen für die aktuell ausgewählte Klasse neu
    func reloadSeatingPositions() {
        loadSeatingPositionsForSelectedClass()
    }

    // Erstellt eine Standardposition für einen Schüler
    private func createDefaultPosition(for studentId: UUID, classId: UUID) -> SeatingPosition {
        // Finde eine freie Position, beginnend bei (0,0)
        var xPos = 0
        var yPos = 0

        // Finde einen freien Platz
        while seatingPositions.contains(where: { $0.xPos == xPos && $0.yPos == yPos }) {
            xPos += 1
            if xPos > 10 {
                xPos = 0
                yPos += 1
            }
        }

        return SeatingPosition(
            studentId: studentId,
            classId: classId,
            xPos: xPos,
            yPos: yPos,
            isCustomPosition: false
        )
    }

    // Aktualisiert die Position eines Schülers
    func updateStudentPosition(studentId: UUID, newX: Int, newY: Int) {
        guard let classId = selectedClassId else { return }

        // Finde die bestehende Position
        if let existingPosition = seatingPositions.first(where: { $0.studentId == studentId }) {
            // Erstelle eine aktualisierte Position
            var updatedPosition = existingPosition
            updatedPosition.xPos = newX
            updatedPosition.yPos = newY
            updatedPosition.lastUpdated = Date()
            updatedPosition.isCustomPosition = true

            // Speichere die aktualisierte Position
            dataStore.updateSeatingPosition(updatedPosition)

            // Aktualisiere auch die lokale Liste
            if let index = seatingPositions.firstIndex(where: { $0.id == existingPosition.id }) {
                seatingPositions[index] = updatedPosition
            }

            print("DEBUG: Position aktualisiert für Schüler \(studentId) auf (\(newX), \(newY))")
        } else {
            // Erstelle eine neue Position, falls keine existiert
            let newPosition = SeatingPosition(
                studentId: studentId,
                classId: classId,
                xPos: newX,
                yPos: newY,
                lastUpdated: Date(),
                isCustomPosition: true
            )
            dataStore.addSeatingPosition(newPosition)
            seatingPositions.append(newPosition)

            print("DEBUG: Neue Position erstellt für Schüler \(studentId) auf (\(newX), \(newY))")
        }
    }

    // Ordnet Schüler automatisch in einem Raster an
    func arrangeStudentsInGrid(columns: Int) {
        guard let classId = selectedClassId else { return }

        print("DEBUG: Ordne Schüler in Raster an (Spalten: \(columns))")
        dataStore.arrangeSeatingPositionsInGrid(classId: classId, columns: columns)
    }

    // Hilfsfunktion, um die Position eines Schülers zu finden
    func getPositionForStudent(_ studentId: UUID) -> SeatingPosition? {
        return seatingPositions.first { $0.studentId == studentId }
    }

    // MARK: - Fehlerbehandlung

    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        print("ERROR: \(message)")
    }

    // Im EnhancedSeatingViewModel
    func addRatingForStudent(studentId: UUID, value: RatingValue) {
        guard let classId = selectedClassId else { return }

        // Neue Bewertung erstellen
        let newRating = Rating(
            studentId: studentId,
            classId: classId,
            value: value
        )

        // Zum DataStore hinzufügen
        dataStore.addRating(newRating)
    }


}


// Diese Methoden zum EnhancedSeatingViewModel hinzufügen

// MARK: - Zusätzliche Schüler-Verwaltungsfunktionen

extension EnhancedSeatingViewModel {
    // Schüler archivieren
    func archiveStudent(_ student: Student) {
        print("Archiviere Schüler: \(student.fullName)")
        var updatedStudent = student
        updatedStudent.isArchived = true
        dataStore.updateStudent(updatedStudent)

        // Liste aktualisieren
        loadStudentsForSelectedClass()
    }

    // Schüler löschen
    func deleteStudent(id: UUID) {
        print("Lösche Schüler mit ID: \(id)")
        dataStore.deleteStudent(id: id)

        // Liste aktualisieren
        loadStudentsForSelectedClass()

        // Entferne auch entsprechende Sitzposition und Abwesenheitsstatus
        if let positionIndex = seatingPositions.firstIndex(where: { $0.studentId == id }) {
            seatingPositions.remove(at: positionIndex)
        }
        absentStudents.remove(id)
    }
}
