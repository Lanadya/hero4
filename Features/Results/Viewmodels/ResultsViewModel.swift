import Foundation
import Combine

class ResultsViewModel: ObservableObject {
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

    private let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()
    }

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

        // Beobachte Änderungen bei den Bewertungen
        dataStore.$ratings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadRatingsForSelectedClass()
            }
            .store(in: &cancellables)
    }

    func loadData() {
        dataStore.loadClasses()
        dataStore.loadStudents()
        dataStore.loadRatings()
    }

    func selectClass(_ id: UUID?) {
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()
        loadRatingsForSelectedClass()
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

    func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            filteredStudents = []
            return
        }

        isLoading = true

        // Hole alle Schüler für die ausgewählte Klasse
        students = dataStore.getStudentsForClass(classId: classId)

        // Nach Nachnamen sortieren
        students.sort { $0.sortableName < $1.sortableName }

        filteredStudents = students

        isLoading = false
    }

    func loadRatingsForSelectedClass() {
        guard let classId = selectedClassId else {
            ratings = []
            uniqueDates = []
            return
        }

        isLoading = true

        // Hole alle Bewertungen für die ausgewählte Klasse
        ratings = dataStore.getRatingsForClass(classId: classId)

        // Extrahiere eindeutige Daten und sortiere sie chronologisch
        let calendar = Calendar.current
        uniqueDates = Array(Set(ratings.map { calendar.startOfDay(for: $0.date) })).sorted()

        isLoading = false
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
            total + (rating.value?.numericValue ?? 0)
        }

        return sum / Double(studentRatings.count)
    }

    func updateRating(studentId: UUID, date: Date, value: RatingValue?) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Prüfen, ob bereits eine Bewertung existiert
        if let existingRating = ratings.first(where: {
            $0.studentId == studentId &&
            calendar.isDate($0.date, inSameDayAs: startOfDay)
        }) {
            // Aktualisiere die bestehende Bewertung
            var updatedRating = existingRating
            updatedRating.value = value
            updatedRating.isAbsent = false // Wenn eine Bewertung gesetzt wird, ist der Schüler anwesend

            dataStore.updateRating(updatedRating)
        } else {
            // Erstelle eine neue Bewertung
            let newRating = Rating(
                studentId: studentId,
                classId: classId,
                date: startOfDay,
                value: value,
                isAbsent: false,
                schoolYear: currentSchoolYear()
            )

            dataStore.addRating(newRating)
        }
    }

    func toggleAbsence(studentId: UUID, date: Date) {
        guard let classId = selectedClassId else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Prüfen, ob bereits eine Bewertung existiert
        if let existingRating = ratings.first(where: {
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

            dataStore.updateRating(updatedRating)
        } else {
            // Erstelle einen neuen Eintrag mit Abwesenheit
            let newRating = Rating(
                studentId: studentId,
                classId: classId,
                date: startOfDay,
                value: nil,
                isAbsent: true,
                schoolYear: currentSchoolYear()
            )

            dataStore.addRating(newRating)
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

    // Im ResultsViewModel hinzufügen:
    func deleteRating(studentId: UUID, date: Date) {
        let calendar = Calendar.current
        if let rating = ratings.first(where: {
            $0.studentId == studentId &&
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            dataStore.deleteRating(id: rating.id)
            // Ratings neu laden
            loadRatingsForSelectedClass()
        }
    }

    func archiveRating(studentId: UUID, date: Date) {
        let calendar = Calendar.current
        if let rating = ratings.first(where: {
            $0.studentId == studentId &&
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            var updatedRating = rating
            updatedRating.isArchived = true
            dataStore.updateRating(updatedRating)
            // Ratings neu laden
            loadRatingsForSelectedClass()
        }
    }


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
