import Foundation
import GRDB

class StudentRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    func getAllStudents() -> [Student] { // Name geändert für Konsistenz
        do {
            return try database.read { db in
                try Student.fetchAll(db)
            }
        } catch {
            print("ERROR: Fehler beim Laden der Studenten: \(error)")
            return []
        }
    }
    func addStudent(_ student: Student) throws {
        try database.write { db in
            try student.insert(db)
        }
    }

    func updateStudent(_ student: Student) throws {
        try database.write { db in
            try student.update(db)
        }
    }

    func deleteStudent(id: UUID) throws {
        try database.write { db in
            try Student.filter(Student.Columns.id == id.uuidString).deleteAll(db)
        }
    }
}
