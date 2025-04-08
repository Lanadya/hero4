import Foundation
import GRDB

// Protokoll für StudentRepository-Schnittstelle
protocol StudentRepositoryProtocol {
    func getStudents() -> [Student]
    func getStudentsForClass(classId: UUID, includeArchived: Bool) -> [Student]
    func addStudent(_ student: Student) -> Student?
    func updateStudent(_ student: Student) -> Bool
    func deleteStudent(id: UUID) -> Bool
    func getStudent(id: UUID) -> Student?
    func archiveStudent(_ student: Student) -> Bool
}

// Direkte GRDB-Implementierung des StudentRepository
class GRDBStudentRepository: StudentRepositoryProtocol {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    func getStudents() -> [Student] {
        do {
            return try database.read { db in
                try Student.fetchAll(db)
            }
        } catch {
            print("ERROR: Fehler beim Laden der Studenten: \(error)")
            return []
        }
    }
    
    func getStudentsForClass(classId: UUID, includeArchived: Bool = false) -> [Student] {
        do {
            return try database.read { db in
                var query = Student.filter(Student.Columns.classId == classId.uuidString)
                
                if !includeArchived {
                    query = query.filter(Student.Columns.isArchived == false)
                }
                
                return try query.fetchAll(db)
            }
        } catch {
            print("ERROR: Fehler beim Laden der Studenten für Klasse: \(error)")
            return []
        }
    }
    
    @discardableResult
    func addStudent(_ student: Student) -> Student? {
        do {
            // Erstelle eine Kopie des Studenten
            let newStudent = student
            try database.write { db in
                try newStudent.save(db)
            }
            return newStudent
        } catch {
            print("ERROR: Fehler beim Hinzufügen des Studenten: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateStudent(_ student: Student) -> Bool {
        do {
            try database.write { db in
                try student.update(db)
            }
            return true
        } catch {
            print("ERROR: Fehler beim Aktualisieren des Studenten: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteStudent(id: UUID) -> Bool {
        do {
            try database.write { db in
                try Student.filter(Student.Columns.id == id.uuidString).deleteAll(db)
            }
            return true
        } catch {
            print("ERROR: Fehler beim Löschen des Studenten: \(error)")
            return false
        }
    }
    
    func getStudent(id: UUID) -> Student? {
        do {
            return try database.read { db in
                try Student.filter(Student.Columns.id == id.uuidString).fetchOne(db)
            }
        } catch {
            print("ERROR: Fehler beim Laden des Studenten: \(error)")
            return nil
        }
    }
    
    @discardableResult
    func archiveStudent(_ student: Student) -> Bool {
        var modifiedStudent = student
        modifiedStudent.isArchived = true
        return updateStudent(modifiedStudent)
    }
}