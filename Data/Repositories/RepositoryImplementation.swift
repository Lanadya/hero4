import Foundation
import Combine

// MARK: - Repository-Implementierungen

/// Implementierung des ClassRepository
final class ClassRepository: ClassRepositoryProtocol {
    private let dataStore: DataStore
    
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }
    
    func getClasses() -> [Class] {
        return dataStore.classes
    }
    
    func addClass(_ classObj: Class) -> Class {
        dataStore.addClass(classObj)
        // Gebe das letzte Element zurück, da es gerade hinzugefügt wurde
        return dataStore.classes.last ?? classObj
    }
    
    func updateClass(_ classObj: Class) -> Class {
        dataStore.updateClass(classObj)
        return classObj
    }
    
    func deleteClass(id: UUID) -> Bool {
        dataStore.deleteClass(id: id)
        return true // Erfolg angenommen (könnte verbessert werden)
    }
    
    func getClass(id: UUID) -> Class? {
        return dataStore.getClass(id: id)
    }
}

/// Implementierung des StudentRepository
final class StudentRepository: StudentRepositoryProtocol {
    private let dataStore: DataStore
    
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }
    
    func getStudents() -> [Student] {
        return dataStore.students
    }
    
    func getStudentsForClass(classId: UUID, includeArchived: Bool = false) -> [Student] {
        return dataStore.getStudentsForClass(classId: classId, includeArchived: includeArchived)
    }
    
    func addStudent(_ student: Student) -> Student {
        dataStore.addStudent(student)
        // Suchen des hinzugefügten Studenten in der Datenquelle
        return dataStore.getStudent(id: student.id) ?? student
    }
    
    func updateStudent(_ student: Student) -> Bool {
        return dataStore.updateStudent(student)
    }
    
    func deleteStudent(id: UUID) -> Bool {
        return dataStore.deleteStudent(id: id)
    }
    
    func getStudent(id: UUID) -> Student? {
        return dataStore.getStudent(id: id)
    }
    
    func archiveStudent(_ student: Student) -> Bool {
        return dataStore.archiveStudent(student)
    }
}

/// Implementierung des RatingRepository
final class RatingRepository: RatingRepositoryProtocol {
    private let dataStore: DataStore
    
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }
    
    func getRatings() -> [Rating] {
        return dataStore.ratings
    }
    
    func getRatingsForStudent(studentId: UUID) -> [Rating] {
        return dataStore.getRatingsForStudent(studentId: studentId)
    }
    
    func getRatingsForClass(classId: UUID, includeArchived: Bool = false) -> [Rating] {
        return dataStore.getRatingsForClass(classId: classId, includeArchived: includeArchived)
    }
    
    func addRating(_ rating: Rating) -> Rating {
        dataStore.addRating(rating)
        return dataStore.getRating(id: rating.id) ?? rating
    }
    
    func updateRating(_ rating: Rating) -> Rating {
        dataStore.updateRating(rating)
        return rating
    }
    
    func deleteRating(id: UUID) -> Bool {
        dataStore.deleteRating(id: id)
        return true // Erfolg angenommen (könnte verbessert werden)
    }
    
    func getRating(id: UUID) -> Rating? {
        return dataStore.getRating(id: id)
    }
}

/// Implementierung des SeatingRepository
final class SeatingRepository: SeatingRepositoryProtocol {
    private let dataStore: DataStore
    
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }
    
    func getSeatingPositions() -> [SeatingPosition] {
        return dataStore.seatingPositions
    }
    
    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition] {
        return dataStore.getSeatingPositionsForClass(classId: classId)
    }
    
    func getSeatingPosition(studentId: UUID, classId: UUID) -> SeatingPosition? {
        return dataStore.getSeatingPosition(studentId: studentId, classId: classId)
    }
    
    func addSeatingPosition(_ position: SeatingPosition) -> SeatingPosition {
        dataStore.addSeatingPosition(position)
        // Finde die hinzugefügte Position in der Datenquelle
        return dataStore.seatingPositions.first { $0.id == position.id } ?? position
    }
    
    func updateSeatingPosition(_ position: SeatingPosition) -> SeatingPosition {
        dataStore.updateSeatingPosition(position)
        return position
    }
    
    func deleteSeatingPosition(id: UUID) -> Bool {
        dataStore.deleteSeatingPosition(id: id)
        return true // Erfolg angenommen (könnte verbessert werden)
    }
}