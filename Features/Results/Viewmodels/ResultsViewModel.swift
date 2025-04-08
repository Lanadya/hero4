import Foundation
import Combine

class ResultsViewModel: ObservableObject {
    // MARK: - Veröffentlichte Eigenschaften für die UI
    @Published var classes: [Class] = []
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var students: [Student] = []
    @Published var filteredStudents: [Student] = []
    @Published var ratings: [Rating] = []
    @Published var uniqueDates: [Date] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    // Notfall-Variablen für Timeout-Mechanismus
    @Published var loadingStartTime: Date?

    // MARK: - Private Eigenschaften
    private let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialSetup = true
    
    // Flag, um zu verfolgen, ob wir gerade auf eine AppState-Änderung reagieren
    private var isRespondingToAppStateChange = false
    
    // Operation IDs für das Tracking
    private var currentStudentsLoadingId: UUID?
    private var currentRatingsLoadingId: UUID?
    
    // MARK: - Initialisierung
    init() {
        setupObservers()
        observeAppState()
    }
    
    deinit {
        // Sicherstellen, dass alle laufenden Operationen abgebrochen werden
        cancelOngoingOperations()
    }
    
    // Force-Reset Methode für den Timeout-Mechanismus
    func forceResetLoadingState() {
        print("⚠️ [ResultsViewModel] Force-resetting loading state")
        isLoading = false
        loadingStartTime = nil
        cancelOngoingOperations()
    }

    // MARK: - Observer
    private func setupObservers() {
        // Beobachte Änderungen bei den Klassen
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] classes in
                guard let self = self else { return }
                self.classes = classes.filter { !$0.isArchived }
                self.updateSelectedClass()
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Schülern via DataStore
        dataStore.$students
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.selectedClassId != nil {
                    self.loadStudentsForSelectedClass()
                }
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Bewertungen via DataStore
        dataStore.$ratings
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.selectedClassId != nil {
                    self.loadRatingsForSelectedClass()
                }
            }
            .store(in: &cancellables)
            
        // Beobachte den Loading-Status
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                let isLoadingStudents = self.currentStudentsLoadingId != nil
                let isLoadingRatings = self.currentRatingsLoadingId != nil
                let newLoadingState = isLoadingStudents || isLoadingRatings
                
                // Nur aktualisieren, wenn sich der Status geändert hat
                if self.isLoading != newLoadingState {
                    DispatchQueue.main.async {
                        self.isLoading = newLoadingState
                        if !newLoadingState {
                            print("🔄 [ResultsViewModel] Loading complete")
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func observeAppState() {
        // Use a much larger debounce to avoid rapid cycling
        AppState.shared.$selectedClassId
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates() // Ignoriere identische Werte
            .receive(on: DispatchQueue.main)
            .sink { [weak self] classId in
                guard let self = self else { return }

                // Only update if it's different from the current selection
                if self.selectedClassId != classId {
                    if !self.isInitialSetup {
                        print("📱 [ResultsViewModel] AppState class selection changed to \(classId?.uuidString ?? "none")")
                    }

                    // Flag that we're responding to an external change
                    self.isRespondingToAppStateChange = true
                    
                    // Canceliere laufende Operationen
                    self.cancelOngoingOperations()
                    
                    self.selectClass(classId)
                    
                    // Reset the flag after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.isRespondingToAppStateChange = false
                    }
                    
                    self.isInitialSetup = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    func loadData() {
        print("📊 [ResultsViewModel] Initial data load")
        
        // Führe die Datenladevorgänge auf einem Hintergrund-Thread aus
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Lade Klassen aus dem DataStore
            self.dataStore.loadClasses()
            
            // Kurze Pause für bessere UI-Reaktion
            Thread.sleep(forTimeInterval: 0.1)
            
            // Die restlichen Daten nur laden, wenn eine Klasse ausgewählt ist
            if self.selectedClassId != nil {
                self.dataStore.loadStudents()
                Thread.sleep(forTimeInterval: 0.1)
                self.dataStore.loadRatings()
            }
        }
    }

    func selectClass(_ id: UUID?) {
        // Skip completely if we're already showing this class
        if selectedClassId == id {
            print("🔄 [ResultsViewModel] Skipping duplicate class selection: \(id?.uuidString ?? "none")")
            return
        }

        print("📋 [ResultsViewModel] Selecting class: \(id?.uuidString ?? "none")")

        // Abbruch laufender Operationen
        cancelOngoingOperations()

        // Set our local ID immediately
        selectedClassId = id

        // Update AppState ONLY if this change ORIGINATED here
        // and we're not already responding to an AppState change
        if !isRespondingToAppStateChange {
            let appStateCurrentId = AppState.shared.selectedClassId
            if appStateCurrentId != id {
                print("🔄 [ResultsViewModel] Updating AppState from ResultsViewModel")
                AppState.shared.setSelectedClass(id, origin: self)
            }
        } else {
            print("🔄 [ResultsViewModel] Skipping AppState update - responding to external change")
        }

        // Now load data
        updateSelectedClass()
        
        // Nur Daten laden, wenn wir eine gültige Klasse haben
        if id != nil {
            loadStudentsForSelectedClass()
            loadRatingsForSelectedClass()
        } else {
            // Bei null-Auswahl Listen leeren
            students = []
            filteredStudents = []
            ratings = []
            uniqueDates = []
        }
    }

    func filterStudents(_ searchText: String) {
        if searchText.isEmpty {
            filteredStudents = students
        } else {
            let lowercasedText = searchText.lowercased()
            filteredStudents = students.filter { student in
                student.firstName.lowercased().contains(lowercasedText) ||
                student.lastName.lowercased().contains(lowercasedText)
            }
        }
    }
    
    // MARK: - Daten abrufen
    func getRatingFor(studentId: UUID, date: Date) -> Rating? {
        let calendar = Calendar.current
        return ratings.first { rating in
            rating.studentId == studentId &&
            calendar.isDate(rating.date, inSameDayAs: date)
        }
    }

    func getAverageRatingFor(studentId: UUID) -> Double? {
        let studentRatings = ratings.filter {
            $0.studentId == studentId &&
            !$0.isAbsent &&
            $0.value != nil
        }

        if studentRatings.isEmpty {
            return nil
        }

        // Berechne den Durchschnitt (1.0 bis 4.0)
        let sum = studentRatings.reduce(0.0) { total, rating in
            total + Double(rating.value?.numericValue ?? 0)
        }

        return sum / Double(studentRatings.count)
    }
    
    // Hilfsfunktion zur Bestimmung des aktuellen Schuljahres
    private func currentSchoolYear() -> String {
        let calendar = Calendar.current
        let currentDate = Date()
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        
        // Wenn wir im ersten Halbjahr sind (August-Dezember), nutzen wir Jahr/Jahr+1
        // z.B. 2024/2025 für August-Dezember 2024
        if month >= 8 {
            return "\(year)/\(year+1)"
        } else {
            // Für Januar-Juli nutzen wir Jahr-1/Jahr
            // z.B. 2023/2024 für Januar-Juli 2024
            return "\(year-1)/\(year)"
        }
    }
    
    // MARK: - Bewertungsoperationen
    func updateRating(studentId: UUID, date: Date, value: RatingValue?) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Auf Hintergrund-Thread ausführen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Prüfen, ob bereits eine Bewertung existiert
            if let existingRating = self.ratings.first(where: {
                $0.studentId == studentId &&
                calendar.isDate($0.date, inSameDayAs: startOfDay)
            }) {
                // Aktualisiere die bestehende Bewertung
                var updatedRating = existingRating
                updatedRating.value = value
                updatedRating.isAbsent = false // Wenn eine Bewertung gesetzt wird, ist der Schüler anwesend

                self.dataStore.updateRating(updatedRating)
            } else {
                // Erstelle eine neue Bewertung
                let newRating = Rating(
                    studentId: studentId,
                    classId: classId,
                    date: startOfDay,
                    value: value,
                    isAbsent: false,
                    schoolYear: self.currentSchoolYear()
                )

                self.dataStore.addRating(newRating)
            }
            
            // Nach kurzer Verzögerung Bewertungen neu laden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.loadRatingsForSelectedClass()
            }
        }
    }

    func toggleAbsence(studentId: UUID, date: Date) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Auf Hintergrund-Thread ausführen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Prüfen, ob bereits eine Bewertung existiert
            if let existingRating = self.ratings.first(where: {
                $0.studentId == studentId &&
                calendar.isDate($0.date, inSameDayAs: startOfDay)
            }) {
                // Abwesenheit umschalten
                var updatedRating = existingRating
                updatedRating.isAbsent = !existingRating.isAbsent

                // Wenn als abwesend markiert, Bewertung entfernen
                if updatedRating.isAbsent {
                    updatedRating.value = nil
                }

                self.dataStore.updateRating(updatedRating)
            } else {
                // Erstelle einen neuen Eintrag mit Abwesenheit
                let newRating = Rating(
                    studentId: studentId,
                    classId: classId,
                    date: startOfDay,
                    value: nil,
                    isAbsent: true,
                    schoolYear: self.currentSchoolYear()
                )

                self.dataStore.addRating(newRating)
            }
            
            // Nach kurzer Verzögerung Bewertungen neu laden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.loadRatingsForSelectedClass()
            }
        }
    }

    func deleteRating(studentId: UUID, date: Date) {
        let calendar = Calendar.current
        
        // Auf Hintergrund-Thread ausführen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let rating = self.ratings.first(where: {
                $0.studentId == studentId &&
                calendar.isDate($0.date, inSameDayAs: date)
            }) {
                self.dataStore.deleteRating(id: rating.id)
                
                // Nach kurzer Verzögerung Bewertungen neu laden
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.loadRatingsForSelectedClass()
                }
            }
        }
    }

    func archiveRating(studentId: UUID, date: Date) {
        let calendar = Calendar.current
        
        // Auf Hintergrund-Thread ausführen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let rating = self.ratings.first(where: {
                $0.studentId == studentId &&
                calendar.isDate($0.date, inSameDayAs: date)
            }) {
                var updatedRating = rating
                updatedRating.isArchived = true
                self.dataStore.updateRating(updatedRating)
                
                // Nach kurzer Verzögerung Bewertungen neu laden
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.loadRatingsForSelectedClass()
                }
            }
        }
    }

    func exportRatings() {
        // Diese Funktion könnte einen CSV-Export oder ähnliches implementieren
        print("Export würde hier implementiert werden")
    }

    func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Private Helper

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
    
    private func cancelOngoingOperations() {
        currentStudentsLoadingId = nil
        currentRatingsLoadingId = nil
    }

    private func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            filteredStudents = []
            return
        }
        
        // Breche alle laufenden Operationen ab
        cancelOngoingOperations()
        
        // Starte eine neue Ladeoperation
        let operationId = UUID()
        currentStudentsLoadingId = operationId
        
        // Setze den Zeitpunkt des Beginns
        loadingStartTime = Date()
        
        // Hintergrundthread verwenden für Datenoperationen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Kurze Verzögerung, um UI-Updates zu ermöglichen
            Thread.sleep(forTimeInterval: 0.1)
            
            // Hole alle Schüler für die ausgewählte Klasse
            let loadedStudents = self.dataStore.getStudentsForClass(classId: classId)
            
            // Nach Nachnamen sortieren
            let sortedStudents = loadedStudents.sorted { $0.sortableName < $1.sortableName }
            
            // Zurück zum Hauptthread für UI-Updates
            DispatchQueue.main.async {
                // Nur aktualisieren, wenn immer noch die gleiche Klasse ausgewählt ist
                // und dies die aktuelle Operation ist
                if self.selectedClassId == classId && self.currentStudentsLoadingId == operationId {
                    self.students = sortedStudents
                    self.filteredStudents = sortedStudents
                    print("✅ [ResultsViewModel] Loaded \(sortedStudents.count) students for class \(classId)")
                    
                    // Operation als erfolgreich beenden
                    if operationId == self.currentStudentsLoadingId {
                        self.currentStudentsLoadingId = nil
                    }
                } else {
                    print("🛑 [ResultsViewModel] Class changed during loading - discarding student results")
                    self.currentStudentsLoadingId = nil
                }
            }
        }
    }

    private func loadRatingsForSelectedClass() {
        guard let classId = selectedClassId else {
            ratings = []
            uniqueDates = []
            return
        }
        
        // Breche alle laufenden Operationen ab
        cancelOngoingOperations()
        
        // Starte eine neue Ladeoperation
        let operationId = UUID()
        currentRatingsLoadingId = operationId
        
        // Setze den Zeitpunkt des Beginns
        loadingStartTime = Date()
        
        // Hintergrundthread verwenden für Datenoperationen
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Kurze Verzögerung, um UI-Updates zu ermöglichen
            Thread.sleep(forTimeInterval: 0.1)
            
            // Hole alle Bewertungen für die ausgewählte Klasse
            let loadedRatings = self.dataStore.getRatingsForClass(classId: classId)
            
            // Extrahiere eindeutige Daten und sortiere sie chronologisch
            let calendar = Calendar.current
            let dates = Array(Set(loadedRatings.map { calendar.startOfDay(for: $0.date) })).sorted()
            
            // Zurück zum Hauptthread für UI-Updates
            DispatchQueue.main.async {
                // Nur aktualisieren, wenn immer noch die gleiche Klasse ausgewählt ist
                // und dies die aktuelle Operation ist
                if self.selectedClassId == classId && self.currentRatingsLoadingId == operationId {
                    self.ratings = loadedRatings
                    self.uniqueDates = dates
                    print("✅ [ResultsViewModel] Loaded \(loadedRatings.count) ratings for class \(classId)")
                    
                    // Operation als erfolgreich beenden
                    if operationId == self.currentRatingsLoadingId {
                        self.currentRatingsLoadingId = nil
                    }
                } else {
                    print("🛑 [ResultsViewModel] Class changed during loading - discarding rating results")
                    self.currentRatingsLoadingId = nil
                }
            }
        }
    }

    // MARK: - Computed Properties

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
}