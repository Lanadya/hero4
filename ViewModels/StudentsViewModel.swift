import Foundation
import Combine

class StudentsViewModel: ObservableObject {
    @Published var selectedClassId: UUID?
    @Published var selectedClass: Class?
    @Published var students: [Student] = []
    @Published var allStudents: [Student] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var globalSearchText: String = ""
    @Published var searchResults: [SearchResult] = []

    private let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    struct SearchResult: Identifiable {
        var id: UUID { student.id }
        var student: Student
        var className: String
    }

    init() {
        // Beobachte Änderungen bei den Schülern im DataStore
        dataStore.$students
            .receive(on: RunLoop.main)
            .sink { [weak self] students in
                self?.allStudents = students.filter { !$0.isArchived }
                self?.loadStudentsForSelectedClass()
                self?.performGlobalSearch()
            }
            .store(in: &cancellables)

        // Beobachte Änderungen bei den Klassen im DataStore
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSelectedClass()
                self?.performGlobalSearch()
            }
            .store(in: &cancellables)
    }

    // MARK: - Klassen-Operationen

    var classes: [Class] {
        return dataStore.classes.filter { !$0.isArchived }
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

    func selectClass(id: UUID?) {
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()
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

    func loadStudentsForSelectedClass() {
        guard let classId = selectedClassId else {
            students = []
            return
        }

        isLoading = true

        // Hole alle Schüler für die ausgewählte Klasse
        let allStudentsForClass = dataStore.getStudentsForClass(classId: classId)

        // Filtern nach Suchtext, wenn vorhanden
        if !searchText.isEmpty {
            let searchTextLower = searchText.lowercased()
            students = allStudentsForClass.filter { student in
                student.firstName.lowercased().contains(searchTextLower) ||
                student.lastName.lowercased().contains(searchTextLower)
            }
        } else {
            students = allStudentsForClass
        }

        isLoading = false
    }

    func getStudentCountForClass(classId: UUID) -> Int {
        return dataStore.getStudentsForClass(classId: classId).count
    }

    func addStudent(_ student: Student) {
        do {
            try student.validate()

            // Prüfen, ob das Limit von 40 Schülern pro Klasse erreicht ist
            let currentCount = getStudentCountForClass(classId: student.classId)
            if currentCount >= 40 {
                showError(message: "Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden.")
                return
            }

            dataStore.addStudent(student)
            loadStudentsForSelectedClass()
        } catch Student.ValidationError.noName {
            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
        } catch {
            showError(message: "Fehler beim Speichern des Schülers: \(error.localizedDescription)")
        }
    }

    func updateStudent(_ student: Student) {
        do {
            try student.validate()
            dataStore.updateStudent(student)
            loadStudentsForSelectedClass()
        } catch Student.ValidationError.noName {
            showError(message: "Bitte geben Sie mindestens einen Vor- oder Nachnamen ein.")
        } catch {
            showError(message: "Fehler beim Aktualisieren des Schülers: \(error.localizedDescription)")
        }
    }

    func deleteStudent(id: UUID) {
        dataStore.deleteStudent(id: id)
        loadStudentsForSelectedClass()
    }

    func archiveStudent(_ student: Student) {
        dataStore.archiveStudent(student)
        loadStudentsForSelectedClass()
    }

    // MARK: - Globale Suche

    func performGlobalSearch() {
        if globalSearchText.isEmpty {
            searchResults = []
            return
        }

        let searchTextLower = globalSearchText.lowercased()
        var results: [SearchResult] = []

        for student in allStudents {
            if student.firstName.lowercased().contains(searchTextLower) ||
               student.lastName.lowercased().contains(searchTextLower) {

                // Klasse für den Schüler finden
                if let classObj = dataStore.getClass(id: student.classId) {
                    results.append(SearchResult(student: student, className: classObj.name))
                }
            }
        }

        searchResults = results
    }

    func updateGlobalSearchText(_ text: String) {
        globalSearchText = text
        performGlobalSearch()
    }

    func clearGlobalSearch() {
        globalSearchText = ""
        searchResults = []
    }

    // MARK: - Klassenbezogene Suche

    func updateSearchText(_ text: String) {
        searchText = text
        loadStudentsForSelectedClass()
    }

    func clearSearch() {
        searchText = ""
        loadStudentsForSelectedClass()
    }

    // MARK: - Fehlerbehandlung

    func showError(message: String) {
        print("FEHLER: \(message)")
        errorMessage = message
        showError = true
    }
}
