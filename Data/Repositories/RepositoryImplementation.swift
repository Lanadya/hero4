import Foundation
import Combine

// MARK: - Repository-Implementierungen

/// DataStore-Implementierung des ClassRepository
final class ClassRepositoryImpl: ClassRepositoryProtocol {
    private let dataStore: DataStore
    
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
    }
    
    func getClasses() -> [Class] {
        return dataStore.classes
    }
    
    func addClass(_ classObj: Class) -> Class? {
        let id = dataStore.addClass(classObj)
        if let id = id, let addedClass = dataStore.getClass(id: id) {
            return addedClass
        }
        return nil
    }
    
    func updateClass(_ classObj: Class) -> Class? {
        dataStore.updateClass(classObj)
        return dataStore.getClass(id: classObj.id)
    }
    
    func deleteClass(id: UUID) -> Bool {
        // Existenz prüfen vor dem Löschen
        guard let _ = dataStore.getClass(id: id) else {
            return false
        }
        
        dataStore.deleteClass(id: id)
        // Prüfen, ob das Löschen erfolgreich war
        return dataStore.getClass(id: id) == nil
    }
    
    func getClass(id: UUID) -> Class? {
        return dataStore.getClass(id: id)
    }
    
    func getClassAt(row: Int, column: Int) -> Class? {
        return dataStore.getClassAt(row: row, column: column)
    }
    
    func archiveClass(_ classObj: Class) -> Bool {
        dataStore.archiveClass(classObj)
        
        // Überprüfen, ob die Archivierung erfolgreich war
        if let updatedClass = dataStore.getClass(id: classObj.id) {
            return updatedClass.isArchived
        }
        return false
    }
}

/// Implementierung des StudentRepository, verwendet nun das definierte Protokoll
final class StudentRepositoryImpl: StudentRepositoryProtocol {
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
    
    func addStudent(_ student: Student) -> Student? {
        dataStore.addStudent(student)
        // Suchen des hinzugefügten Studenten in der Datenquelle
        return dataStore.getStudent(id: student.id)
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

/// Verbesserte Implementierung des RatingRepository
final class RatingRepositoryImpl: RatingRepositoryProtocol {
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
    
    func addRating(_ rating: Rating) -> Rating? {
        dataStore.addRating(rating)
        return dataStore.getRating(id: rating.id)
    }
    
    func updateRating(_ rating: Rating) -> Rating? {
        dataStore.updateRating(rating)
        return dataStore.getRating(id: rating.id)
    }
    
    func deleteRating(id: UUID) -> Bool {
        // Existenz prüfen vor dem Löschen
        guard let _ = dataStore.getRating(id: id) else {
            return false
        }
        
        dataStore.deleteRating(id: id)
        
        // Prüfen, ob das Löschen erfolgreich war
        return dataStore.getRating(id: id) == nil
    }
    
    func getRating(id: UUID) -> Rating? {
        return dataStore.getRating(id: id)
    }
}

/// Verbesserte Implementierung des SeatingRepository
final class SeatingRepositoryImpl: SeatingRepositoryProtocol {
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
    
    func addSeatingPosition(_ position: SeatingPosition) -> SeatingPosition? {
        dataStore.addSeatingPosition(position)
        // Finde die hinzugefügte Position in der Datenquelle
        return dataStore.seatingPositions.first { $0.id == position.id }
    }
    
    func updateSeatingPosition(_ position: SeatingPosition) -> SeatingPosition? {
        dataStore.updateSeatingPosition(position)
        return dataStore.seatingPositions.first { $0.id == position.id }
    }
    
    func deleteSeatingPosition(id: UUID) -> Bool {
        // Prüfen, ob die Position existiert vor dem Löschen
        let exists = dataStore.seatingPositions.contains { $0.id == id }
        if !exists {
            return false
        }
        
        dataStore.deleteSeatingPosition(id: id)
        
        // Prüfen, ob das Löschen erfolgreich war
        return !dataStore.seatingPositions.contains { $0.id == id }
    }
    
    func arrangeSeatingGrid(classId: UUID, columns: Int) -> Bool {
        // Validierung der Parameter
        if columns <= 0 {
            return false
        }
        
        // Automatische Anordnung der Sitzplätze im Raster
        dataStore.arrangeSeatingPositionsInGrid(classId: classId, columns: columns)
        return true
    }
}