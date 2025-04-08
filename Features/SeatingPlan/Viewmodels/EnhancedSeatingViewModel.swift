import Foundation
import Combine
import GRDB
import CoreUtilities

// LoadingManager Klasse wird direkt im Projekt gefunden, kein spezieller Import notwendig

@MainActor
class EnhancedSeatingViewModel: ObservableObject {
    
    // Hilfsfunktion zur Ermittlung des aktuellen Schuljahres
    func currentSchoolYear() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        // Wenn wir in der zweiten Hälfte des Schuljahres sind (Januar-Juli)
        if month < 8 {
            return "\(year-1)/\(year)"
        } else {
            // Erste Hälfte des Schuljahres (August-Dezember)
            return "\(year)/\(year+1)"
        }
    }
    
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
    var isRespondingToAppStateChange = false
    
    // Zugriff auf den LoadingManager für koordinierte Ladeoperationen
    private let loadingManager = LoadingManager.shared
    
    // Tracking-IDs für LoadingManager-Operationen
    private var currentClassLoadingId: UUID?
    private var currentStudentsLoadingId: UUID?
    private var currentPositionsLoadingId: UUID?
    
    // Speichert den Zeitpunkt der letzten Anordnung pro Klassenraum
    private var lastArrangementTimes: [String: Date] = [:]

    private var isInitialSetup = true

    // DataStore reference
    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize observers
        setupObservers()
        observeAppState()
    }
    
    deinit {
        // Sicherstellen, dass alle laufenden Operationen abgebrochen werden
        cancelAllOperations()
    }
    
    nonisolated private func cancelAllOperations() {
        // Wir erstellen eine Task für den Main Actor
        Task { @MainActor in
            // Alle laufenden Ladeoperationen abbrechen
            if let id = self.currentClassLoadingId {
                await self.loadingManager.endLoading(category: "seating_classes", operationId: id, success: false)
                self.currentClassLoadingId = nil
            }
            if let id = self.currentStudentsLoadingId {
                await self.loadingManager.endLoading(category: "seating_students", operationId: id, success: false)
                self.currentStudentsLoadingId = nil
            }
            if let id = self.currentPositionsLoadingId {
                await self.loadingManager.endLoading(category: "seating_positions", operationId: id, success: false)
                self.currentPositionsLoadingId = nil
            }
        }
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

    private func observeAppState() {
        // Use a much larger debounce to avoid rapid cycling
        AppState.shared.$selectedClassId
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] classId in
                guard let self = self else { return }

                // Only update if it's different from the current selection
                // and we're not currently loading a class
                if self.selectedClassId != classId && !self.isLoadingClass {
                    if !self.isInitialSetup {
                        print("EnhancedSeatingViewModel: AppState class selection changed to \(classId?.uuidString ?? "none")")
                    }

                    // Flag that we're responding to an external change
                    self.isRespondingToAppStateChange = true
                    
                    // Abbruch aller laufenden Operationen
                    self.cancelAllOperations()
                    
                    // Async Aufruf in Task einbetten
                    Task {
                        await self.selectClass(classId)
                        // Reset the flag after the selection is done
                        self.isRespondingToAppStateChange = false
                        self.isInitialSetup = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Class Operations

    @discardableResult
    func loadClasses() async -> Bool {
        print("DEBUG: Loading classes")
        
        // Abbruch laufender Operationen
        if let id = currentClassLoadingId {
            try? await Task.sleep(for: .nanoseconds(10))
            await loadingManager.endLoading(category: "seating_classes", operationId: id, success: false)
        }
        
        // Neue Ladeoperation starten
        try? await Task.sleep(for: .nanoseconds(10))
        let operationId = await loadingManager.startLoading(category: "seating_classes", timeout: 5.0)
        currentClassLoadingId = operationId
        
        // Daten im Hintergrund laden
        do {
            // Eine kleine Verzögerung für ein echtes async-Verhalten
            try await Task.sleep(for: .milliseconds(10))
            
            // Daten in einem isolierten Task laden
            _ = await Task.detached {
                // Kurze Verzögerung vor MainActor-Aufruf
                try? await Task.sleep(for: .nanoseconds(10))
                
                await MainActor.run {
                    self.dataStore.loadClasses()
                }
            }.value
        } catch {
            print("Error during sleep: \(error)")
        }
        
        // Operation als abgeschlossen markieren
        try? await Task.sleep(for: .nanoseconds(10))
        await loadingManager.endLoading(category: "seating_classes", operationId: operationId, success: true)
        if currentClassLoadingId == operationId {
            currentClassLoadingId = nil
        }
        return true
    }
    
    @MainActor
    func selectClass(_ id: UUID?) async {
        // Skip completely if we're already showing this class
        if selectedClassId == id {
            return
        }

        print("DEBUG: Selecting class in EnhancedSeatingViewModel: \(id?.uuidString ?? "none")")

        // Prevent parallel loading processes
        if isLoadingClass {
            print("DEBUG: Class loading already in progress - aborting")
            return
        }

        isLoadingClass = true

        // Set our local ID immediately
        selectedClassId = id

        // Save active class in UserDefaults for app-wide synchronization
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: "activeSeatingPlanClassId")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeSeatingPlanClassId")
        }

        // Update AppState ONLY if this change ORIGINATED here
        // and we're not already responding to an AppState change
        if !isRespondingToAppStateChange {
            let appStateCurrentId = AppState.shared.selectedClassId
            if appStateCurrentId != id {
                print("DEBUG: Updating AppState from EnhancedSeatingViewModel")
                AppState.shared.setSelectedClass(id, origin: self)
            }
        } else {
            print("DEBUG: Skipping AppState update since we're responding to AppState change")
        }

        // Now load all necessary data
        updateSelectedClass()
        
        // Füge eine kurze asynchrone Verzögerung hinzu, um ein echtes await zu haben
        try? await Task.sleep(for: .nanoseconds(10))
        
        // Load data
        loadStudentsForSelectedClass()
        loadSeatingPositionsForSelectedClass()

        // Reset absence status when changing classes
        absentStudents.removeAll()

        // Reset loading state
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
        
        Task {
            // Abbruch laufender Operationen
            if let id = currentStudentsLoadingId {
                // Verzögerung durch Hilfsmethode garantieren
                await ensureAsync()
                await loadingManager.endLoading(category: "seating_students", operationId: id, success: false)
            }
            
            // Neue Ladeoperation starten
            await ensureAsync() // Garantiert asynchrone Operation
            let operationId = await loadingManager.startLoading(category: "seating_students", timeout: 5.0)
            currentStudentsLoadingId = operationId
            
            // Schüler für die ausgewählte Klasse laden
            let loadedStudents = dataStore.getStudentsForClass(classId: classId)
            
            // Operation als abgeschlossen markieren
            if selectedClassId == classId {
                students = loadedStudents
                print("DEBUG: Loaded \(loadedStudents.count) students for class \(classId)")
            }
            
            await ensureAsync() // Garantiert asynchrone Operation
            await loadingManager.endLoading(category: "seating_students", operationId: operationId, success: true)
            if currentStudentsLoadingId == operationId {
                currentStudentsLoadingId = nil
            }
        }
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
        if let index = students.firstIndex(where: { $0.id == studentId }) {
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
        
        Task {
            // Abbruch laufender Operationen
            if let id = currentPositionsLoadingId {
                await ensureAsync() // Garantiert asynchrone Operation
                await loadingManager.endLoading(category: "seating_positions", operationId: id, success: false)
            }
            
            // Neue Ladeoperation starten
            await ensureAsync() // Garantiert asynchrone Operation
            let operationId = await loadingManager.startLoading(category: "seating_positions", timeout: 5.0)
            currentPositionsLoadingId = operationId
            
            // Load existing positions
            let loadedPositions = dataStore.seatingPositions.filter { $0.classId == classId }
            
            // Nur fortfahren, wenn immer noch die gleiche Klasse ausgewählt ist
            if selectedClassId != classId {
                await ensureAsync() // Garantiert asynchrone Operation
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: false)
                return
            }
            
            seatingPositions = loadedPositions
            print("DEBUG: Loaded \(loadedPositions.count) seating positions for class \(classId)")
            
            // Prüfen, ob bereits ein Sitzplan existiert
            let hasCustomPositions = loadedPositions.contains { $0.isCustomPosition }
            let hasAnyPositions = !loadedPositions.isEmpty
            
            // Sicherstellen, dass wir nicht schon mitten in einer Anordnung sind
            if isArrangingStudents {
                print("DEBUG: Student arrangement already in progress - skipping automatic arrangement")
                await ensureAsync() // Garantiert asynchrone Operation
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                if currentPositionsLoadingId == operationId {
                    currentPositionsLoadingId = nil
                }
                return
            }
            
            // WICHTIG: Nur einmal pro Klassenwechsel die Schüler anordnen und Wiederholungen vermeiden
            if !hasAnyPositions || (!hasCustomPositions && students.count > 0) {
                // Lasse mindestens 10 Sekunden zwischen wiederholten Anordnungen vergehen
                let now = Date()
                let classIdString = classId.uuidString
                
                if let lastArrangement = lastArrangementTimes[classIdString], 
                   now.timeIntervalSince(lastArrangement) < 10.0 {
                    print("DEBUG: Skipping arrangement - already arranged recently (within 10 seconds)")
                    
                    // Trotzdem individuelle Schüler ohne Position mit Standardpositionen versehen
                    createDefaultPositionsForStudentsWithoutPositions(classId: classId)
                    await ensureAsync() // Garantiert asynchrone Operation
                    await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                    if currentPositionsLoadingId == operationId {
                        currentPositionsLoadingId = nil
                    }
                    return
                }
                
                // Bei Erstanlage (keine Positionen) oder wenn keine benutzerdefinierten Positionen existieren,
                // aber Schüler vorhanden sind, arrangiere die Schüler in der Ecke
                print("DEBUG: No custom seating plan exists - arranging students in corner")
                
                await ensureAsync() // Garantiert asynchrone Operation
                await arrangeStudentsInCorner()
                await ensureAsync() // Garantiert asynchrone Operation
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                if currentPositionsLoadingId == operationId {
                    currentPositionsLoadingId = nil
                }
            } else {
                // Füge Standardpositionen für Schüler ohne Position hinzu
                createDefaultPositionsForStudentsWithoutPositions(classId: classId)
                await ensureAsync() // Garantiert asynchrone Operation
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                if currentPositionsLoadingId == operationId {
                    currentPositionsLoadingId = nil
                }
            }
        }
    }
    
    // Separate Methode für die Zuweisung von Standardpositionen an neue Schüler
    private func createDefaultPositionsForStudentsWithoutPositions(classId: UUID) {
        // Sammeln aller fehlenden Positionen, um sie in einem Batch hinzuzufügen
        var positionsToAdd: [SeatingPosition] = []
        
        for student in students {
            if !seatingPositions.contains(where: { $0.studentId == student.id }) {
                // Create a default position
                let defaultPosition = createDefaultPosition(for: student.id, classId: classId)
                positionsToAdd.append(defaultPosition)
            }
        }
        
        // Wenn neue Positionen erstellt werden müssen
        if !positionsToAdd.isEmpty {
            // Füge sie zu lokalen Positionen hinzu
            seatingPositions.append(contentsOf: positionsToAdd)
            
            // Füge sie in einem einzigen Batch zur Datenbank hinzu
            dataStore.addSeatingPositions(positionsToAdd)
            
            print("DEBUG: Added \(positionsToAdd.count) default positions for students without positions")
        }
    }

    // Arrange students initially in the corner of the room
    @MainActor
    func arrangeStudentsInCorner() async {
        guard let classId = selectedClassId else { return }
        
        // Wenn bereits eine Anordnung läuft, diese nicht erneut starten
        if isArrangingStudents {
            print("DEBUG: Already arranging students - skipping duplicate request")
            return
        }
        
        // Zusätzliche Sicherheitsprüfung - Vermeide mehrfache Anordnungen
        let now = Date()
        let classIdString = classId.uuidString
        if let lastArrangement = lastArrangementTimes[classIdString], 
           now.timeIntervalSince(lastArrangement) < 5.0 {
            print("DEBUG: Skipping arrangement - already arranged recently (within 5 seconds)")
            return
        }
        
        // Anordnungsprozess starten und tracken
        isArrangingStudents = true
        print("DEBUG: Arranging students in corner")
        
        // Zeit der Anordnung für diese Klasse speichern
        lastArrangementTimes[classIdString] = now

        // Kurze Verzögerung für UI-Updates - echte async-Operation
        do {
            try await Task.sleep(for: .milliseconds(100)) // 0.1 Sekunden
            // Direkt ausführen, da wir bereits in einer async-Funktion sind
            await performArrangementInCornerAsync(classId: classId)
        }
        catch {
            print("Error during arrangement sleep: \(error)")
            isArrangingStudents = false
        }
    }
    
    // Eigentliche Implementierung der Anordnung (zur Trennung von Zeitsteuerung)
    private func performArrangementInCornerAsync(classId: UUID) async {
        // Stelle sicher, dass wir eine echte Task haben
        try? await Task.sleep(for: .nanoseconds(10))
        
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
        
        // Kleine Verzögerung für Task-Wechsel
        try? await Task.sleep(for: .nanoseconds(10))
        
        // Batch-Update der lokalen Array
        for position in positionsToUpdate {
            if let index = seatingPositions.firstIndex(where: { $0.id == position.id }) {
                seatingPositions[index] = position
            }
        }
        seatingPositions.append(contentsOf: positionsToAdd)
        
        // Kopien für den Zugriff im Task erstellen
        let positionsToUpdateCopy = positionsToUpdate
        let positionsToAddCopy = positionsToAdd
        
        // Task für den Datenbank-Update
        await MainActor.run {
            // Batch-Update der DataStore-Array - alle in einem Schritt
            var positions = dataStore.seatingPositions
            
            // Zuerst Updates
            for position in positionsToUpdateCopy {
                if let index = positions.firstIndex(where: { $0.id == position.id }) {
                    positions[index] = position
                }
            }
            
            // Dann Neuzugänge
            positions.append(contentsOf: positionsToAddCopy)
            
            // Nur ein einziger Schreibvorgang
            dataStore.seatingPositions = positions
            
            // Notify of changes - nach allem
            objectWillChange.send()
            print("DEBUG: Arranged \(sortedStudents.count) students in the corner")
        }
        
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

    // Dictionary zur Verfolgung der letzten Persistierungszeit pro StudentID
    private var lastPersistTimes: [UUID: Date] = [:]
    private var pendingPositionUpdates: [UUID: (position: SeatingPosition, isNew: Bool)] = [:]
    
    // Actors für isolierte Speicherung von positionUpdateTimer
    actor PositionUpdateTracker {
        var pendingUpdates: [UUID: (position: SeatingPosition, isNew: Bool)] = [:]
        var lastPersistTimes: [UUID: Date] = [:]
        private var timerTask: Task<Void, Never>? = nil
        
        func recordPendingUpdate(studentId: UUID, position: SeatingPosition, isNew: Bool) {
            pendingUpdates[studentId] = (position, isNew)
        }
        
        func recordPersistTime(studentId: UUID, time: Date) {
            lastPersistTimes[studentId] = time
        }
        
        func getPendingUpdate(for studentId: UUID) -> (position: SeatingPosition, isNew: Bool)? {
            return pendingUpdates[studentId]
        }
        
        func getLastPersistTime(for studentId: UUID) -> Date? {
            return lastPersistTimes[studentId]
        }
        
        func getAllPendingUpdates() -> [UUID: (position: SeatingPosition, isNew: Bool)] {
            return pendingUpdates
        }
        
        func clearPendingUpdate(for studentId: UUID) {
            pendingUpdates.removeValue(forKey: studentId)
        }
        
        func clearAllPendingUpdates() {
            pendingUpdates.removeAll()
        }
        
        func scheduleProcessing(after seconds: TimeInterval, action: @escaping () async -> Void) {
            // Cancel any existing timer
            timerTask?.cancel()
            
            // Schedule a new timer
            timerTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                
                // Check if task was cancelled during sleep
                if !Task.isCancelled {
                    await action()
                }
            }
        }
        
        func cancelScheduledProcessing() {
            timerTask?.cancel()
            timerTask = nil
        }
    }
    
    private let positionTracker = PositionUpdateTracker()
    
    // Verbesserte Drosselung für Positionsänderungen mit Batch-Updates
    private func throttledPersistPosition(_ position: SeatingPosition, isNew: Bool) {
        Task {
            let now = Date()
            let throttleInterval: TimeInterval = 0.1 // 100ms
            
            // Zuerst überprüfen wir, ob wir zu schnell aktualisieren würden
            let lastTime = await positionTracker.getLastPersistTime(for: position.studentId)
            
            if let lastTime = lastTime, 
               now.timeIntervalSince(lastTime) < throttleInterval {
                // Anstatt sofort zu aktualisieren, merken wir uns die Position für später
                await positionTracker.recordPendingUpdate(studentId: position.studentId, position: position, isNew: isNew)
                
                // Timer für das Batch-Update starten
                await positionTracker.scheduleProcessing(after: 0.5) {
                    await self.processPendingPositionUpdates()
                }
            } else {
                // Direkt speichern, da die Drosselung nicht greift
                await positionTracker.recordPersistTime(studentId: position.studentId, time: now)
                persistPositionImmediately(position, isNew: isNew)
            }
        }
    }
    
    private func persistPositionImmediately(_ position: SeatingPosition, isNew: Bool) {
        Task { @MainActor in
            // Daten persistieren
            var positions = dataStore.seatingPositions
            
            if isNew {
                positions.append(position)
            } else if let index = positions.firstIndex(where: { $0.id == position.id }) {
                positions[index] = position
            }
            
            dataStore.seatingPositions = positions
        }
    }
    
    private func processPendingPositionUpdates() async {
        // Echte asynchrone Operation mit Task.detached statt Task.sleep
        let _ = try? await Task.detached {
            // Echtzeit-Verzögerung 
            try await Task.sleep(for: .milliseconds(1))
            return "async context"
        }.value
        
        // Alle ausstehenden Updates vom Actor holen
        let updates = await positionTracker.getAllPendingUpdates()
        
        // Wenn nichts zu aktualisieren ist, abbrechen
        if updates.isEmpty { return }
        
        print("DEBUG: Processing \(updates.count) pending position updates in batch")
        
        // Expliziter asynchroner Kontext für MainActor.run
        let updatesCopy = updates // Kopie der Updates erstellen
        let _ = try? await Task.detached {
            try await Task.sleep(for: .milliseconds(1))
            return "pre-mainactor context"
        }.value
        
        // DataStore nur auf dem MainActor aktualisieren
        await MainActor.run {
            // Batch-Update in der Datenbank
            var positions = dataStore.seatingPositions
            
            // Alle Updates direkt anwenden
            for (_, update) in updatesCopy {
                let position = update.position
                let isNew = update.isNew
                
                // Update anwenden
                if isNew {
                    positions.append(position)
                } else if let index = positions.firstIndex(where: { $0.id == position.id }) {
                    positions[index] = position
                }
            }
            
            // In einem Schritt in der Datenbank aktualisieren
            dataStore.seatingPositions = positions
        }
        
        // Zeiten aktualisieren - wir machen dies außerhalb des MainActor-Blocks,
        // damit wir den Actor-Aufruf haben, der ein echtes 'await' benötigt
        for (_, update) in updates {
            await positionTracker.recordPersistTime(studentId: update.position.studentId, time: Date())
        }
        
        // Pending-Liste leeren
        await positionTracker.clearAllPendingUpdates()
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
        
        // Kopien erstellen für den Zugriff im Task
        let updatedPositionCopy = updatedPosition
        let isNewPositionCopy = isNewPosition
        
        // Optimierte Aktualisierung der lokalen Arrays und der Datenbank
        Task { @MainActor in
            // Lokale Array aktualisieren
            if isNewPositionCopy {
                seatingPositions.append(updatedPositionCopy)
            } else if let index = seatingPositions.firstIndex(where: { $0.id == updatedPositionCopy.id }) {
                seatingPositions[index] = updatedPositionCopy
            }
            
            // DataStore Array aktualisieren - Nur einmal pro Student pro 100ms
            // Dies verhindert zu viele Schreibvorgänge bei Drag-Operationen
            throttledPersistPosition(updatedPositionCopy, isNew: isNewPositionCopy)
            
            print("DEBUG: \(isNewPositionCopy ? "Created" : "Updated") position for student \(studentId) to (\(newX), \(newY))")
        }
    }

    // Arrange students in a grid automatically
    @MainActor
    func arrangeStudentsInGrid(columns: Int) async {
        guard selectedClassId != nil else { return }
        print("DEBUG: Arranging students in grid (columns: \(columns))")

        // Sort students by last name
        let sortedStudents = students.sorted { $0.lastName < $1.lastName }

        for (index, student) in sortedStudents.enumerated() {
            let row = index / columns
            let col = index % columns

            // Update or create position for each student
            updateStudentPosition(studentId: student.id, newX: col, newY: row)
            
            // Kurze Pause einlegen, um den UI nicht zu blockieren - echte async-Operation
            if index % 10 == 0 && index > 0 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 Sekunden
            }
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
            Task {
                await loadStudentsForSelectedClass()
            }
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
            Task {
                await loadStudentsForSelectedClass()
            }
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

    // Komplette Neuimplementierung ohne MainActor.run-Aufrufe
    func loadClassData() async {
        guard let classId = selectedClassId else { return }
        
        // Garantiere echte asynchrone Operation
        await ensureAsync()
        
        // Operation starten
        let loadingId = await loadingManager.startLoading(category: "class")
        
        do {
            // Simuliere Ladevorgang mit echter asynchroner Operation
            for _ in 0..<3 {
                try await Task.sleep(for: .milliseconds(30))
                await Task.yield()
            }
            
            // Laden einer Klasse umsetzen - in einer separaten asynchronen Task
            let loadTask = Task<Class?, Error> { 
                // Versuche, die Klasse aus dem DataStore zu laden
                if let existingClass = dataStore.getClass(id: classId) {
                    return existingClass
                } else {
                    throw NSError(domain: "ClassLoadingError", code: 404, 
                                 userInfo: [NSLocalizedDescriptionKey: "Klasse nicht gefunden"])
                }
            }
            
            // Warten auf das Ergebnis der Task - echte asynchrone Operation
            if let loadedClass = try await loadTask.value {
                // Direktes Setzen der Klasse ohne MainActor.run
                self.selectedClass = loadedClass
            }
            
            // Operation als erfolgreich beenden
            await ensureAsync()
            await loadingManager.endLoading(category: "class", operationId: loadingId, success: true)
            
        } catch {
            // Operation als fehlgeschlagen beenden
            await ensureAsync()
            await loadingManager.endLoading(category: "class", operationId: loadingId, success: false)
            
            // Warten auf asynchrone Operation vor Fehlerbehandlung
            await ensureAsync()
            
            // Fehler direkt anzeigen ohne MainActor.run
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    // Diese Hilfsmethode wird jetzt nicht mehr benötigt, da wir keine Datenbank-Simulation mehr haben
    // Sie bleibt als Referenz, falls wir sie später wieder benötigen
    private func loadClassFromDatabase(classId: UUID) async throws -> Class {
        await ensureAsync()
        
        if let existingClass = dataStore.getClass(id: classId) {
            return existingClass
        } else {
            throw NSError(domain: "ClassLoadingError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Klasse nicht gefunden"
            ])
        }
    }

    // Hilfsmethode, die garantiert eine asynchrone Operation darstellt
    private func ensureAsync() async {
        // Verwende Task.yield und Task.sleep zusammen für ein garantiertes Suspend
        await Task.yield()
        do {
            try await Task.sleep(for: .nanoseconds(1))
        } catch {
            // Fehler ignorieren, da es sich um einen minimalen Sleep handelt
            print("Sleep error ignored: \(error)")
        }
        await Task.yield()
    }
    
    // Hilfsmethode, die garantiert eine asynchrone Operation mit Wert zurückgibt
    private func ensureAsyncWithValue<T>(_ value: T) async -> T {
        // Verwende Task.yield und Task.sleep zusammen für ein garantiertes Suspend
        await Task.yield()
        do {
            try await Task.sleep(for: .nanoseconds(1))
        } catch {
            // Fehler ignorieren, da es sich um einen minimalen Sleep handelt
            print("Sleep error ignored: \(error)")
        }
        await Task.yield()
        return value
    }
}
