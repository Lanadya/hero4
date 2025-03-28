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
        selectedClassId = id
        updateSelectedClass()
        loadStudentsForSelectedClass()
        loadSeatingPositionsForSelectedClass()
        // Reset absence status when changing classes
        absentStudents.removeAll()
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

    func isStudentAbsent(_ studentId: UUID) -> Bool {
        return absentStudents.contains(studentId)
    }

    // Update student notes
    func updateStudentNotes(studentId: UUID, notes: String) {
        if let index = students.firstIndex(where: { $0.id == studentId }) {
            var updatedStudent = students[index]
            updatedStudent.notes = notes.isEmpty ? nil : notes

            // Update student in database
            dataStore.updateStudent(updatedStudent)

            print("DEBUG: Updated notes for student \(studentId)")
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
        print("DEBUG: Loaded \(seatingPositions.count) seating positions")

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

    // Arrange students initially in the corner of the room
    func arrangeStudentsInCorner() {
        guard let classId = selectedClassId else { return }
        print("DEBUG: Arranging students in corner")

        // Sort students by last name
        let sortedStudents = students.sorted { $0.lastName < $1.lastName }

        // Check if custom positions already exist
        let hasCustomPositions = seatingPositions.contains { $0.isCustomPosition }
        if hasCustomPositions {
            print("DEBUG: Skipping arrangement - Custom positions already exist")
            return
        }

        // Starting position in the corner (top left)
        let startX = 0
        let startY = 0

        // Position of stacked students
        for (index, student) in sortedStudents.enumerated() {
            // Calculate position with slight offset (up to 3 students per row)
            let xPos = startX + (index % 3)
            let yPos = startY + (index / 3)

            // Create or update position
            if let existingPosition = seatingPositions.first(where: { $0.studentId == student.id }) {
                var updatedPosition = existingPosition
                updatedPosition.xPos = xPos
                updatedPosition.yPos = yPos
                updatedPosition.isCustomPosition = false // Don't mark as custom

                // Save the position to our local array and DataStore
                if let index = seatingPositions.firstIndex(where: { $0.id == existingPosition.id }) {
                    seatingPositions[index] = updatedPosition

                    // Update in DataStore array
                    var positions = dataStore.seatingPositions
                    if let dsIndex = positions.firstIndex(where: { $0.id == existingPosition.id }) {
                        positions[dsIndex] = updatedPosition
                        dataStore.seatingPositions = positions
                    }
                }
            } else {
                // Create new position
                let newPosition = SeatingPosition(
                    studentId: student.id,
                    classId: classId,
                    xPos: xPos,
                    yPos: yPos,
                    isCustomPosition: false
                )
                seatingPositions.append(newPosition)

                // Add to DataStore array
                var positions = dataStore.seatingPositions
                positions.append(newPosition)
                dataStore.seatingPositions = positions
            }
        }

        // Notify of changes
        objectWillChange.send()
        print("DEBUG: Arranged \(sortedStudents.count) students in the corner")
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

    // Update a student's position
    func updateStudentPosition(studentId: UUID, newX: Int, newY: Int) {
        guard let classId = selectedClassId else { return }

        // Find the existing position
        if let existingPosition = seatingPositions.first(where: { $0.studentId == studentId }) {
            // Create an updated position
            var updatedPosition = existingPosition
            updatedPosition.xPos = newX
            updatedPosition.yPos = newY
            updatedPosition.lastUpdated = Date()
            updatedPosition.isCustomPosition = true

            // Update the local array
            if let index = seatingPositions.firstIndex(where: { $0.id == existingPosition.id }) {
                seatingPositions[index] = updatedPosition

                // Update in DataStore array
                var positions = dataStore.seatingPositions
                if let dsIndex = positions.firstIndex(where: { $0.id == existingPosition.id }) {
                    positions[dsIndex] = updatedPosition
                    dataStore.seatingPositions = positions
                }
            }

            print("DEBUG: Updated position for student \(studentId) to (\(newX), \(newY))")
        } else {
            // Create a new position if none exists
            let newPosition = SeatingPosition(
                studentId: studentId,
                classId: classId,
                xPos: newX,
                yPos: newY,
                lastUpdated: Date(),
                isCustomPosition: true
            )
            seatingPositions.append(newPosition)

            // Add to DataStore array
            var positions = dataStore.seatingPositions
            positions.append(newPosition)
            dataStore.seatingPositions = positions

            print("DEBUG: Created new position for student \(studentId) at (\(newX), \(newY))")
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
        dataStore.updateStudent(updatedStudent)

        // Update list
        loadStudentsForSelectedClass()
    }

    // Delete student
    func deleteStudent(id: UUID) {
        print("Deleting student with ID: \(id)")
        dataStore.deleteStudent(id: id)

        // Update list
        loadStudentsForSelectedClass()

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
