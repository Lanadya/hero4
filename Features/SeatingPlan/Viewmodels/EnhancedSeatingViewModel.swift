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
    
    private func cancelAllOperations() {
        // Alle laufenden Ladeoperationen abbrechen
        if let id = currentClassLoadingId {
            loadingManager.endLoading(category: "seating_classes", operationId: id, success: false)
            currentClassLoadingId = nil
        }
        if let id = currentStudentsLoadingId {
            loadingManager.endLoading(category: "seating_students", operationId: id, success: false)
            currentStudentsLoadingId = nil
        }
        if let id = currentPositionsLoadingId {
            loadingManager.endLoading(category: "seating_positions", operationId: id, success: false)
            currentPositionsLoadingId = nil
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
                    
                    self.selectClass(classId)
                    // Reset the flag after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isRespondingToAppStateChange = false
                    }
                    self.isInitialSetup = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Class Operations

    func loadClasses() async {
        print("DEBUG: Loading classes")
        
        // Abbruch laufender Operationen
        if let id = currentClassLoadingId {
            await loadingManager.endLoading(category: "seating_classes", operationId: id, success: false)
        }
        
        do {
            // Neue Ladeoperation starten
            let operationId = await loadingManager.startLoading(category: "seating_classes", timeout: 5.0)
            currentClassLoadingId = operationId
            
            // Daten im Hintergrund laden
            try await Task {
                await dataStore.loadClasses()
                
                // Operation als abgeschlossen markieren
                await loadingManager.endLoading(category: "seating_classes", operationId: operationId, success: true)
                if currentClassLoadingId == operationId {
                    currentClassLoadingId = nil
                }
            }.value
        } catch {
            print("⚠️ [EnhancedSeatingViewModel] Class loading failed: \(error)")
            if let id = currentClassLoadingId {
                await loadingManager.endLoading(category: "seating_classes", operationId: id, success: false)
                currentClassLoadingId = nil
            }
        }
    }
    
    func selectClass(_ id: UUID?) {
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
        Task {
            await loadStudentsForSelectedClass()
        }
        Task {
            await loadSeatingPositionsForSelectedClass()
        }

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

    private func loadStudentsForSelectedClass() async {
        guard let classId = selectedClassId else {
            students = []
            return
        }
        
        do {
            // Abbruch laufender Operationen
            if let id = currentStudentsLoadingId {
                await loadingManager.endLoading(category: "seating_students", operationId: id, success: false)
            }
            
            // Neue Ladeoperation starten
            let operationId = await loadingManager.startLoading(category: "seating_students", timeout: 5.0)
            currentStudentsLoadingId = operationId
            
            // Schüler für die ausgewählte Klasse laden
            let loadedStudents = await dataStore.getStudentsForClass(classId: classId)
            
            // Operation als abgeschlossen markieren
            if selectedClassId == classId {
                students = loadedStudents
                print("DEBUG: Loaded \(loadedStudents.count) students for class \(classId)")
            }
            
            await loadingManager.endLoading(category: "seating_students", operationId: operationId, success: true)
            if currentStudentsLoadingId == operationId {
                currentStudentsLoadingId = nil
            }
        } catch {
            print("⚠️ [EnhancedSeatingViewModel] Student loading failed: \(error)")
            if let id = currentStudentsLoadingId {
                await loadingManager.endLoading(category: "seating_students", operationId: id, success: false)
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
    private func loadSeatingPositionsForSelectedClass() async {
        guard let classId = selectedClassId else {
            seatingPositions = []
            return
        }
        
        do {
            // Abbruch laufender Operationen
            if let id = currentPositionsLoadingId {
                await loadingManager.endLoading(category: "seating_positions", operationId: id, success: false)
            }
            
            // Neue Ladeoperation starten
            let operationId = await loadingManager.startLoading(category: "seating_positions", timeout: 5.0)
            currentPositionsLoadingId = operationId
            
            // Load existing positions
            let loadedPositions = await dataStore.seatingPositions.filter { $0.classId == classId }
            
            // Nur fortfahren, wenn immer noch die gleiche Klasse ausgewählt ist
            if selectedClassId != classId {
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
                    await createDefaultPositionsForStudentsWithoutPositions(classId: classId)
                    await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                    if currentPositionsLoadingId == operationId {
                        currentPositionsLoadingId = nil
                    }
                    return
                }
                
                // Bei Erstanlage (keine Positionen) oder wenn keine benutzerdefinierten Positionen existieren,
                // aber Schüler vorhanden sind, arrangiere die Schüler in der Ecke
                print("DEBUG: No custom seating plan exists - arranging students in corner")
                
                await arrangeStudentsInCorner()
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                if currentPositionsLoadingId == operationId {
                    currentPositionsLoadingId = nil
                }
            } else {
                // Füge Standardpositionen für Schüler ohne Position hinzu
                await createDefaultPositionsForStudentsWithoutPositions(classId: classId)
                await loadingManager.endLoading(category: "seating_positions", operationId: operationId, success: true)
                if currentPositionsLoadingId == operationId {
                    currentPositionsLoadingId = nil
                }
            }
        } catch {
            print("⚠️ [EnhancedSeatingViewModel] Position loading failed: \(error)")
            if let id = currentPositionsLoadingId {
                await loadingManager.endLoading(category: "seating_positions", operationId: id, success: false)
                currentPositionsLoadingId = nil
            }
        }
    }
    
    // Separate Methode für die Zuweisung von Standardpositionen an neue Schüler
    private func createDefaultPositionsForStudentsWithoutPositions(classId: UUID) async {
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
            await dataStore.addSeatingPositions(positionsToAdd)
            
            print("DEBUG: Added \(positionsToAdd.count) default positions for students without positions")
        }
    }

    // Arrange students initially in the corner of the room
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

        // Ausführung verzögern, um anderen Prozessen Zeit zu geben, abzuschließen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isArrangingStudents else { return }
            self.performArrangementInCorner(classId: classId)
        }
    }
    
    // Eigentliche Implementierung der Anordnung (zur Trennung von Zeitsteuerung)
    private func performArrangementInCorner(classId: UUID) {
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
        
        // In einem separaten Thread ausführen, um Blockierungen zu vermeiden
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Batch-Update der DataStore-Array - alle in einem Schritt
            var positions = self.dataStore.seatingPositions
            
            // Zuerst Updates
            for position in positionsToUpdate {
                if let index = positions.firstIndex(where: { $0.id == position.id }) {
                    positions[index] = position
                }
            }
            
            // Dann Neuzugänge
            positions.append(contentsOf: positionsToAdd)
            
            // Nur ein einziger Schreibvorgang
            self.dataStore.seatingPositions = positions
            
            // Zurück zum Hauptthread für UI-Updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Notify of changes - nach allem
                self.objectWillChange.send()
                print("DEBUG: Arranged \(sortedStudents.count) students in the corner")
                
                // Anordnungsprozess beenden
                self.isArrangingStudents = false
            }
        }
    }

    // Reload seating positions for the currently selected class
    func reloadSeatingPositions() {
        Task {
            await loadSeatingPositionsForSelectedClass()
        }
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
    private var positionUpdateTimer: Timer? = nil
    
    // Verbesserte Drosselung für Positionsänderungen mit Batch-Updates
    private func throttledPersistPosition(_ position: SeatingPosition, isNew: Bool) {
        let now = Date()
        let throttleInterval: TimeInterval = 0.1 // 100ms
        
        // Zuerst überprüfen wir, ob wir zu schnell aktualisieren würden
        if let lastTime = lastPersistTimes[position.studentId], 
           now.timeIntervalSince(lastTime) < throttleInterval {
            // Anstatt sofort zu aktualisieren, merken wir uns die Position für später
            pendingPositionUpdates[position.studentId] = (position, isNew)
            
            // Stelle sicher, dass der Timer läuft
            if positionUpdateTimer == nil {
                startPositionUpdateTimer()
            }
            return
        }
        
        // Zeit aktualisieren
        lastPersistTimes[position.studentId] = now
        
        // Aktualisierung auf Hintergrund-Thread ausführen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Daten persistieren
            var positions = self.dataStore.seatingPositions
            
            if isNew {
                positions.append(position)
            } else if let index = positions.firstIndex(where: { $0.id == position.id }) {
                positions[index] = position
            }
            
            self.dataStore.seatingPositions = positions
        }
    }
    
    // Startet einen Timer, der ausstehende Positionsänderungen in regelmäßigen Abständen verarbeitet
    private func startPositionUpdateTimer() {
        positionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, !self.pendingPositionUpdates.isEmpty else {
                self?.stopPositionUpdateTimer()
                return
            }
            
            // Kopiere und leere die ausstehenden Updates
            let updatesCopy = self.pendingPositionUpdates
            self.pendingPositionUpdates = [:]
            
            // Verarbeite alle ausstehenden Updates in einem Batch
            let now = Date()
            DispatchQueue.global(qos: .userInitiated).async {
                var positions = self.dataStore.seatingPositions
                
                for (studentId, update) in updatesCopy {
                    // Aktualisiere den Zeitstempel
                    self.lastPersistTimes[studentId] = now
                    
                    if update.isNew {
                        positions.append(update.position)
                    } else if let index = positions.firstIndex(where: { $0.id == update.position.id }) {
                        positions[index] = update.position
                    }
                }
                
                // Ein Schreibvorgang für alle Änderungen
                self.dataStore.seatingPositions = positions
            }
        }
    }
    
    private func stopPositionUpdateTimer() {
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
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

    // Example of how to use the new loading manager
    func loadClassData() async {
        guard let classId = selectedClassId else { return }
        
        let loadingId = await loadingManager.startLoading(category: "class")
        defer {
            Task {
                await loadingManager.endLoading(category: "class", operationId: loadingId, success: true)
            }
        }
        
        do {
            // Your existing loading logic here
            // Make sure to use async/await for any asynchronous operations
            let loadedClass = try await loadClassFromDatabase(classId: classId)
            await MainActor.run {
                self.selectedClass = loadedClass
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    // Helper function to load class from database
    private func loadClassFromDatabase(classId: UUID) async throws -> Class {
        // Implement your database loading logic here
        // Make sure to use async/await for database operations
        return try await withCheckedThrowingContinuation { continuation in
            // Your existing database loading code here
            // Call continuation.resume(returning:) when done
            // or continuation.resume(throwing:) if there's an error
        }
    }
}
