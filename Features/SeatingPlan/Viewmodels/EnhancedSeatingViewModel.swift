import Foundation
import Combine
import GRDB

class EnhancedSeatingViewModel: ObservableObject {
    // Published variables for the view
    @Published var students: [Student] = []
    @Published var classes: [Class] = []
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var seatingPositions: [SeatingPosition] = []
    @Published var absentStudents: Set<UUID> = [] // Variable for absent students
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Interner Status zum Tracking gleichzeitiger Operationen
    var isArrangingStudents = false
    var isLoadingClass = false
    
    // Speichert den Zeitpunkt der letzten Anordnung pro Klassenraum
    private var lastArrangementTimes: [String: Date] = [:]

    // DataStore reference
    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize observers
        setupObservers()
    }

    // MARK: - Data Observation

    private func setupObservers() {
        // Observe changes in classes
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] classes in
                self?.classes = classes.filter { !$0.isArchived }
                self?.updateSelectedClass()
            }
            .store(in: &cancellables)

        // Observe changes in students
        dataStore.$students
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadStudentsForSelectedClass()
            }
            .store(in: &cancellables)

        // Observe changes in seating positions
        dataStore.$seatingPositions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadSeatingPositionsForSelectedClass()
            }
            .store(in: &cancellables)
    }

    // MARK: - Class Operations

    func loadClasses() {
        print("DEBUG: Loading classes")
        dataStore.loadClasses()
    }

    func selectClass(_ id: UUID?) {
        print("DEBUG: Selecting class: \(id?.uuidString ?? "none")")
        
        // Vermeiden von Überladung wenn dieselbe Klasse erneut ausgewählt wird
        if selectedClassId == id && !students.isEmpty {
            print("DEBUG: Klasse ist bereits ausgewählt - kein erneutes Laden nötig")
            return
        }
        
        // Verhindern von parallelen Ladeprozessen
        if isLoadingClass {
            print("DEBUG: Klassenladung läuft bereits - wird abgebrochen")
            return
        }
        
        isLoadingClass = true
        selectedClassId = id
        
        // Aktive Klasse in UserDefaults speichern für App-übergreifende Synchronisation
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: "activeSeatingPlanClassId")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeSeatingPlanClassId")
        }
        
        updateSelectedClass()
        loadStudentsForSelectedClass()
        loadSeatingPositionsForSelectedClass()
        // Reset absence status when changing classes
        absentStudents.removeAll()
        
        // Ladezustand zurücksetzen
        isLoadingClass = false
    }

    private func updateSelectedClass() {
        if let classId = selectedClassId {
            selectedClass = dataStore.getClass(id: classId)

            // If the selected class no longer exists, set to nil
            if selectedClass == nil {
                selectedClassId = nil
            }
        } else {
            selectedClass = nil
        }
    }

    // Classes grouped by weekday
    var classesByWeekday: [(weekday: String, classes: [Class])] {
        let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]

        var result: [(weekday: String, classes: [Class])] = []

        for (index, weekday) in weekdays.enumerated() {
            let column = index + 1
            let classesForDay = classes.filter { $0.column == column && !$0.isArchived }.sorted { $0.row < $1.row }

            if !classesForDay.isEmpty {
                result.append((weekday: weekday, classes: classesForDay))
            }
        }

        return result
    }

    // MARK: - Student Operations

    private func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            return
        }

        students = dataStore.getStudentsForClass(classId: classId)
        print("DEBUG: Loaded \(students.count) students for class")
    }

    // MARK: - Absence Management

    // Update student absence status and synchronize with database
    func updateStudentAbsenceStatus(studentId: UUID, isAbsent: Bool) {
        // Update in-memory status
        if isAbsent {
            absentStudents.insert(studentId)
        } else {
            absentStudents.remove(studentId)
        }

        // Update in database
        synchronizeAbsenceWithDatabase(studentId: studentId, isAbsent: isAbsent)

        print("DEBUG: Set absence status for student \(studentId) to \(isAbsent ? "absent" : "present")")
        objectWillChange.send()
    }

    // Synchronize absence status with database
    private func synchronizeAbsenceWithDatabase(studentId: UUID, isAbsent: Bool) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if a rating already exists for today
        if let existingRating = dataStore.ratings.first(where: { rating in
            rating.studentId == studentId &&
            calendar.isDate(rating.date, inSameDayAs: today) &&
            !rating.isArchived
        }) {
            // Update existing rating
            var updatedRating = existingRating
            updatedRating.isAbsent = isAbsent
            // Important: Do NOT remove rating if student is marked as present

            dataStore.updateRating(updatedRating)
            print("DEBUG: Updated existing rating entry for student \(studentId) (isAbsent: \(isAbsent))")
        } else if isAbsent {
            // Only if absent, create new rating entry
            let newRating = Rating(
                studentId: studentId,
                classId: classId,
                date: today,
                value: nil,
                isAbsent: true,
                isArchived: false,
                createdAt: Date(),
                schoolYear: currentSchoolYear()
            )

            dataStore.addRating(newRating)
            print("DEBUG: Created new rating entry for absent student \(studentId)")
        }
    }

    // MARK: - Rating Functions

    // Add a new rating or update existing one
    func addRatingForStudent(studentId: UUID, value: RatingValue) {
        guard let classId = selectedClassId else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let existingRating = dataStore.ratings.first(where: { rating in
            rating.studentId == studentId &&
            calendar.isDate(rating.date, inSameDayAs: today) &&
            !rating.isArchived
        }) {
            var updatedRating = existingRating
            updatedRating.value = value
            updatedRating.isAbsent = false
            dataStore.updateRating(updatedRating)
            if absentStudents.contains(studentId) {
                absentStudents.remove(studentId)
            }
        } else {
            let newRating = Rating(
                studentId: studentId,
                classId: classId,
                date: today,
                value: value,
                isAbsent: false,
                isArchived: false,
                createdAt: Date(),
                schoolYear: currentSchoolYear()
            )
            dataStore.addRating(newRating)
            if absentStudents.contains(studentId) {
                updateStudentAbsenceStatus(studentId: studentId, isAbsent: false)
            }
        }
        objectWillChange.send()
    }


    // Specifically for absent students - creates an entry without rating but with absence status
    func addRatingForAbsentStudent(studentId: UUID) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if a rating already exists for today
        if let existingRating = dataStore.ratings.first(where: { rating in
            rating.studentId == studentId &&
            calendar.isDate(rating.date, inSameDayAs: today) &&
            !rating.isArchived
        }) {
            // Update existing rating
            var updatedRating = existingRating
            updatedRating.isAbsent = true
            // When absent, remove rating
            updatedRating.value = nil
            dataStore.updateRating(updatedRating)
            print("DEBUG: Marked student \(studentId) as absent")
        } else {
            // Create new rating with absence status
            let newRating = Rating(
                studentId: studentId,
                classId: classId,
                date: today,
                value: nil,
                isAbsent: true,
                isArchived: false,
                createdAt: Date(),
                schoolYear: currentSchoolYear()
            )
            dataStore.addRating(newRating)
            print("DEBUG: Created new absence marking for student \(studentId)")
        }

        // Update UI
        objectWillChange.send()
    }
    
    /// Gibt die Anzahl der heute vergebenen Bewertungen zurück
    func getTodaysRatingsCount() -> Int {
        guard let classId = selectedClassId else { return 0 }
        
        // Heutiges Datum
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Alle Bewertungen für die aktuelle Klasse laden
        let allRatings = dataStore.ratings.filter { rating in
            rating.classId == classId &&
            !rating.isArchived &&
            calendar.isDate(rating.date, inSameDayAs: today)
        }
        
        return allRatings.count
    }

    func isStudentAbsent(_ studentId: UUID) -> Bool {
        return absentStudents.contains(studentId)
    }

    // Update student notes
    func updateStudentNotes(studentId: UUID, notes: String) {
        if let index = students.firstIndex(where
                                           : { $0.id == studentId }) {
            var updatedStudent = students[index]
            updatedStudent.notes = notes.isEmpty ? nil : notes

            // Update student in database
            let success = dataStore.updateStudent(updatedStudent)
            if success {
                print("DEBUG: Updated notes for student \(studentId)")
            } else {
                print("ERROR: Failed to update notes for student \(studentId)")
            }
        }
    }

    // MARK: - Seating Position Operations
    private func loadSeatingPositionsForSelectedClass() {
        guard let classId = selectedClassId else {
            seatingPositions = []
            return
        }

        // Load existing positions
        seatingPositions = dataStore.seatingPositions.filter { $0.classId == classId }
        print("DEBUG: Loaded \(seatingPositions.count) seating positions for class \(classId)")
        
        // Prüfen, ob bereits ein Sitzplan existiert
        let hasCustomPositions = seatingPositions.contains { $0.isCustomPosition }
        let hasAnyPositions = !seatingPositions.isEmpty
        
        // WICHTIG: Nur einmal pro Klassenwechsel die Schüler anordnen und Wiederholungen vermeiden
        if !hasAnyPositions || (!hasCustomPositions && students.count > 0 && !isArrangingStudents) {
            // Lasse mindestens 10 Sekunden zwischen wiederholten Anordnungen vergehen
            let now = Date()
            let classId = selectedClassId?.uuidString ?? "unknown"
            
            if let lastArrangement = lastArrangementTimes[classId], 
               now.timeIntervalSince(lastArrangement) < 10.0 {
                print("DEBUG: Skipping arrangement - already arranged recently")
                return
            }
            
            // Bei Erstanlage (keine Positionen) oder wenn keine benutzerdefinierten Positionen existieren,
            // aber Schüler vorhanden sind, arrangiere die Schüler in der Ecke
            print("DEBUG: No custom seating plan exists - arranging students in corner")
            arrangeStudentsInCorner()
            
            // Zeitpunkt der letzten Anordnung für diese Klasse speichern
            lastArrangementTimes[classId] = now
        } else {
            // For students without a position, create a default position
            for student in students {
                if !seatingPositions.contains(where: { $0.studentId == student.id }) {
                    // Create a default position
                    let defaultPosition = createDefaultPosition(for: student.id, classId: classId)
                    seatingPositions.append(defaultPosition)

                    // Add the position to the DataStore
                    var positions = dataStore.seatingPositions
                    positions.append(defaultPosition)
                    dataStore.seatingPositions = positions
                }
            }
        }
    }

    // Arrange students initially in the corner of the room
    func arrangeStudentsInCorner() {
        guard let classId = selectedClassId else { return }
        
        // Wenn bereits eine Anordnung läuft, diese nicht erneut starten
        if isArrangingStudents {
            print("DEBUG: Already arranging students - skipping duplicate request")
            return
        }
        
        // Anordnungsprozess starten und tracken
        isArrangingStudents = true
        print("DEBUG: Arranging students in corner")

        // Sort students by last name
        let sortedStudents = students.sorted { $0.lastName < $1.lastName }

        // Check if custom positions already exist
        let hasCustomPositions = seatingPositions.contains { $0.isCustomPosition }
        if hasCustomPositions {
            print("DEBUG: Skipping arrangement - Custom positions already exist")
            isArrangingStudents = false
            return
        }
        
        // Batch-Operationen vorbereiten, um die Datenbank-Schreibvorgänge zu optimieren
        var positionsToUpdate: [SeatingPosition] = []
        var positionsToAdd: [SeatingPosition] = []

        // Starting position in the corner (top left)
        let startX = 0
        let startY = 0

        // Position of stacked students
        for (index, student) in sortedStudents.enumerated() {
            // Calculate position with slight offset (up to 3 students per row)
            let xPos = startX + (index % 3)
            let yPos = startY + (index / 3)

            // Create or update position in Batches
            if let existingPosition = seatingPositions.first(where: { $0.studentId == student.id }) {
                var updatedPosition = existingPosition
                updatedPosition.xPos = xPos
                updatedPosition.yPos = yPos
                updatedPosition.isCustomPosition = false
                
                positionsToUpdate.append(updatedPosition)
            } else {
                // Create new position
                let newPosition = SeatingPosition(
                    studentId: student.id,
                    classId: classId,
                    xPos: xPos,
                    yPos: yPos,
                    isCustomPosition: false
                )
                positionsToAdd.append(newPosition)
            }
        }
        
        // Batch-Update der lokalen Array
        for position in positionsToUpdate {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions[index] = position
            }
        }
        seatingPositions.append(contentsOf: positionsToAdd)
        
        // Batch-Update der DataStore-Array - alle in einem Schritt
        var positions = dataStore.seatingPositions
        
        // Zuerst Updates
        for position in positionsToUpdate {
            if let index = positions.firstIndex(where: { $0.id == position.id }) {
                positions[index] = position
            }
        }
        
        // Dann Neuzugänge
        positions.append(contentsOf: positionsToAdd)
        
        // Nur ein einziger Schreibvorgang
        dataStore.seatingPositions = positions

        // Notify of changes - nach allem
        objectWillChange.send()
        print("DEBUG: Arranged \(sortedStudents.count) students in the corner")
        
        // Anordnungsprozess beenden
        isArrangingStudents = false
    }

    // Reload seating positions for the currently selected class
    func reloadSeatingPositions() {
        loadSeatingPositionsForSelectedClass()
    }

    // Create a default position for a student
    private func createDefaultPosition(for studentId: UUID, classId: UUID) -> SeatingPosition {
        // Find a free position, starting at (0,0)
        var xPos = 0
        var yPos = 0

        // Find a free spot
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

    // Update a student's position with Batch-Operationen
    func updateStudentPosition(studentId: UUID, newX: Int, newY: Int) {
        guard let classId = selectedClassId else { return }
        
        // Finde die bestehende Position oder erstelle eine neue
        var updatedPosition: SeatingPosition
        var isNewPosition = false
        
        if let existingPosition = seatingPositions.first(where: { $0.studentId == studentId }) {
            // Position aktualisieren
            updatedPosition = existingPosition
            updatedPosition.xPos = newX
            updatedPosition.yPos = newY
            updatedPosition.lastUpdated = Date()
            updatedPosition.isCustomPosition = true
        } else {
            // Neue Position erstellen
            updatedPosition = SeatingPosition(
                studentId: studentId,
                classId: classId,
                xPos: newX,
                yPos: newY,
                lastUpdated: Date(),
                isCustomPosition: true
            )
            isNewPosition = true
        }
        
        // Optimierte Aktualisierung der lokalen Arrays und der Datenbank
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Lokale Array aktualisieren
            if isNewPosition {
                self.seatingPositions.append(updatedPosition)
            } else if let index = self.seatingPositions.firstIndex(where: { $0.id == updatedPosition.id }) {
                self.seatingPositions[index] = updatedPosition
            }
            
            // DataStore Array aktualisieren - Nur einmal pro Student pro 100ms
            // Dies verhindert zu viele Schreibvorgänge bei Drag-Operationen
            throttledPersistPosition(updatedPosition, isNew: isNewPosition)
            
            print("DEBUG: \(isNewPosition ? "Created" : "Updated") position for student \(studentId) to (\(newX), \(newY))")
        }
    }
    
    // Dictionary zur Verfolgung der letzten Persistierungszeit pro StudentID
    private var lastPersistTimes: [UUID: Date] = [:]
    
    // Gedrosselte Persistierungsfunktion für Positionen
    private func throttledPersistPosition(_ position: SeatingPosition, isNew: Bool) {
        let now = Date()
        let throttleInterval: TimeInterval = 0.1 // 100ms
        
        // Nur aktualisieren, wenn seit der letzten Persistierung die Mindestzeit vergangen ist
        if let lastTime = lastPersistTimes[position.studentId], 
           now.timeIntervalSince(lastTime) < throttleInterval {
            return
        }
        
        // Zeit aktualisieren
        lastPersistTimes[position.studentId] = now
        
        // Daten persistieren
        var positions = dataStore.seatingPositions
        
        if isNew {
            positions.append(position)
        } else if let index = positions.firstIndex(where: { $0.id == position.id }) {
            positions[index] = position
        }
        
        dataStore.seatingPositions = positions
    }

    // Arrange students in a grid automatically
    func arrangeStudentsInGrid(columns: Int) {
        guard selectedClassId != nil else { return }
        print("DEBUG: Arranging students in grid (columns: \(columns))")

        // Sort students by last name
        let sortedStudents = students.sorted { $0.lastName < $1.lastName }

        for (index, student) in sortedStudents.enumerated() {
            let row = index / columns
            let col = index % columns

            // Update or create position for each student
            updateStudentPosition(studentId: student.id, newX: col, newY: row)
        }

        objectWillChange.send()
    }

    // Helper function to find a student's position
    func getPositionForStudent(_ studentId: UUID) -> SeatingPosition? {
        return seatingPositions.first { $0.studentId == studentId }
    }

    // MARK: - Error Handling

    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        print("ERROR: \(message)")
    }

    // MARK: - Student Management Functions

    // Archive student
    func archiveStudent(_ student: Student) {
        print("Archiving student: \(student.fullName)")
        var updatedStudent = student
        updatedStudent.isArchived = true
        let success = dataStore.updateStudent(updatedStudent)
        
        if success {
            // Update list
            loadStudentsForSelectedClass()
        } else {
            print("ERROR: Failed to archive student \(student.fullName)")
        }
    }

    // Delete student
    func deleteStudent(id: UUID) {
        print("Deleting student with ID: \(id)")
        let success = dataStore.deleteStudent(id: id)
        
        if success {
            // Update list
            loadStudentsForSelectedClass()
        } else {
            print("ERROR: Failed to delete student with ID: \(id)")
        }

        // Also remove corresponding seating position and absence status
        if let positionIndex = seatingPositions.firstIndex(where: { $0.studentId == id }) {
            seatingPositions.remove(at: positionIndex)

            // Update in DataStore array
            var positions = dataStore.seatingPositions
            positions.removeAll { $0.studentId == id }
            dataStore.seatingPositions = positions
        }
        absentStudents.remove(id)
    }
}
