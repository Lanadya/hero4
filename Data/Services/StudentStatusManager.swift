import Foundation
import Combine

class StudentStatusManager {
    static let shared = StudentStatusManager()
    private let dataStore = DataStore.shared

    // Reaktiver Publisher für UI-Updates
    let statusChangePublisher = PassthroughSubject<StudentStatusChange, Never>()

    struct StudentStatusChange {
        enum ChangeType {
            case created, updated, deleted, archived, restored, moved

            var description: String {
                switch self {
                case .created: return "erstellt"
                case .updated: return "aktualisiert"
                case .deleted: return "gelöscht"
                case .archived: return "archiviert"
                case .restored: return "wiederhergestellt"
                case .moved: return "verschoben"
                }
            }
        }

        let studentId: UUID
        let studentName: String
        let type: ChangeType
        let success: Bool
    }

    // Generische Methode für Statusänderungen
    func performStatusChange(
        for studentIds: [UUID],
        operation: @escaping (UUID) -> Bool,
        changeType: StudentStatusChange.ChangeType,
        onComplete: @escaping (Int, Int) -> Void
    ) {
        var successCount = 0
        var failureCount = 0

        print("DEBUG StatusManager: Starting batch operation \(changeType.description) for \(studentIds.count) students")

        // Create a dispatch group to track operation completion
        let dispatchGroup = DispatchGroup()

        for studentId in studentIds {
            dispatchGroup.enter()

            // Check if the student exists
            guard let student = dataStore.getStudent(id: studentId) else {
                print("DEBUG StatusManager: Student \(studentId) not found, skipping")
                failureCount += 1
                dispatchGroup.leave()
                continue
            }

            print("DEBUG StatusManager: Processing \(changeType.description) for \(student.fullName) (ID: \(studentId))")

            // Run the operation and get the result
            let success = operation(studentId)

            if success {
                successCount += 1
                print("DEBUG StatusManager: ✅ Success \(changeType.description) for \(student.fullName)")

                // Send status change notification
                statusChangePublisher.send(StudentStatusChange(
                    studentId: studentId,
                    studentName: student.fullName,
                    type: changeType,
                    success: true
                ))
            } else {
                failureCount += 1
                print("DEBUG StatusManager: ❌ Failed \(changeType.description) for \(student.fullName)")

                // Send status change notification for failure
                statusChangePublisher.send(StudentStatusChange(
                    studentId: studentId,
                    studentName: student.fullName,
                    type: changeType,
                    success: false
                ))
            }

            dispatchGroup.leave()
        }

        // When all operations are complete, call the completion handler
        dispatchGroup.notify(queue: .main) {
            print("DEBUG StatusManager: Completed batch operation with \(successCount) successes and \(failureCount) failures")
            onComplete(successCount, failureCount)
        }
    }

    // MARK: - Specific Operations

    // Enhanced delete implementation with more detailed logging
    func deleteStudents(ids: [UUID], onComplete: @escaping (Int, Int) -> Void) {
        print("DEBUG StatusManager: deleteStudents called with \(ids.count) students: \(ids)")

        // Make more detailed logs
        for id in ids {
            if let student = dataStore.getStudent(id: id) {
                print("DEBUG StatusManager: Will attempt to delete student: \(student.fullName) (ID: \(id))")
            } else {
                print("DEBUG StatusManager: Warning: Student with ID \(id) not found before deletion attempt")
            }
        }

        performStatusChange(
            for: ids,
            operation: { studentId -> Bool in
                print("DEBUG StatusManager: Executing DELETE operation for student ID: \(studentId)")
                let result = self.dataStore.deleteStudent(id: studentId)
                print("DEBUG StatusManager: Delete result for \(studentId): \(result ? "SUCCESS" : "FAILURE")")
                return result
            },
            changeType: .deleted,
            onComplete: onComplete
        )
    }

    // Enhanced archive implementation with more detailed logging
    func archiveStudents(ids: [UUID], onComplete: @escaping (Int, Int) -> Void) {
        print("DEBUG StatusManager: archiveStudents called with \(ids.count) students: \(ids)")

        // Make more detailed logs
        for id in ids {
            if let student = dataStore.getStudent(id: id) {
                print("DEBUG StatusManager: Will attempt to archive student: \(student.fullName) (ID: \(id))")
            } else {
                print("DEBUG StatusManager: Warning: Student with ID \(id) not found before archive attempt")
            }
        }

        performStatusChange(
            for: ids,
            operation: { studentId -> Bool in
                guard let student = self.dataStore.getStudent(id: studentId) else {
                    print("DEBUG StatusManager: Student not found for archiving: \(studentId)")
                    return false
                }

                print("DEBUG StatusManager: Executing ARCHIVE operation for \(student.fullName)")
                var archivedStudent = student
                archivedStudent.isArchived = true

                let result = self.dataStore.updateStudent(archivedStudent)
                print("DEBUG StatusManager: Archive result for \(studentId): \(result ? "SUCCESS" : "FAILURE")")
                return result
            },
            changeType: .archived,
            onComplete: onComplete
        )
    }

    func moveStudentToClass(_ studentId: UUID, _ newClassId: UUID) -> Bool {
        guard let student = dataStore.getStudent(id: studentId) else {
            print("DEBUG StatusManager: Cannot move student \(studentId) - not found")
            return false
        }

        let oldClassId = student.classId
        print("DEBUG StatusManager: Moving student \(student.fullName) from class \(oldClassId) to \(newClassId)")

        // 1. Archiviere Bewertungen aus der alten Klasse
        let ratingsToArchive = dataStore.getRatingsForStudent(studentId: studentId)
            .filter { $0.classId == oldClassId }

        for var rating in ratingsToArchive {
            rating.isArchived = true
            dataStore.updateRating(rating)
        }
        print("DEBUG StatusManager: Archived \(ratingsToArchive.count) ratings for student \(studentId)")

        // 2. Aktualisiere die Klasse des Schülers
        var updatedStudent = student
        updatedStudent.classId = newClassId
        let updateResult = dataStore.updateStudent(updatedStudent)
        print("DEBUG StatusManager: Updated student class: \(updateResult)")

        // 3. Passe die Sitzposition an
        if let oldPosition = dataStore.getSeatingPosition(studentId: studentId, classId: oldClassId) {
            dataStore.deleteSeatingPosition(id: oldPosition.id)
            print("DEBUG StatusManager: Deleted old seating position")
        }

        // 4. Erstelle eine neue Sitzposition
        let newPosition = SeatingPosition(
            studentId: studentId,
            classId: newClassId,
            xPos: 0,
            yPos: 0
        )
        dataStore.addSeatingPosition(newPosition)
        print("DEBUG StatusManager: Created new seating position")

        // 5. Sende Statusänderungsbenachrichtigung
        statusChangePublisher.send(StudentStatusChange(
            studentId: studentId,
            studentName: student.fullName,
            type: .moved,
            success: true
        ))

        return true
    }
}
