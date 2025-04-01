import GRDB
import Foundation

class ClassRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getAllClasses() -> [Class] {
        do {
            return try dbQueue.read { db in
                try Class.fetchAll(db)
            }
        } catch {
            print("Fehler beim Laden der Klassen: \(error)")
            return []
        }
    }

    func getClass(id: UUID) -> Class? {
        do {
            return try dbQueue.read { db in
                try Class.filter(Column("id") == id.uuidString).fetchOne(db)
            }
        } catch {
            print("Fehler beim Laden der Klasse: \(error)")
            return nil
        }
    }

    func getClassAt(row: Int, column: Int) -> Class? {
        do {
            return try dbQueue.read { db in
                try Class.filter(Column("row") == row && Column("column") == column).fetchOne(db)
            }
        } catch {
            print("Fehler beim Laden der Klasse an Position (\(row), \(column)): \(error)")
            return nil
        }
    }

    func addClass(_ cls: Class) throws {
        try dbQueue.write { db in
            try cls.insert(db)
        }
    }

    func updateClass(_ cls: Class) throws {
        try dbQueue.write { db in
            try cls.update(db)
        }
    }

    func deleteClass(id: UUID) throws {
        try dbQueue.write { db in
            try Class.filter(Column("id") == id.uuidString).deleteAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try Class.deleteAll(db)
        }
    }
}

//import Foundation
//import GRDB
//
//class ClassRepository {
//    private let dbQueue: DatabaseQueue
//
//    init(dbQueue: DatabaseQueue) {
//        self.dbQueue = dbQueue
//    }
//
//    // Alle Klassen abrufen
//    func getAllClasses() throws -> [Class] {
//        try dbQueue.read { db in
//            try Class.fetchAll(db)
//        }
//    }
//
//    // Eine Klasse hinzufügen
//    func addClass(_ cls: Class) throws {
//        try dbQueue.inTransaction { db in
//            try cls.insert(db)
//            return .commit
//        }
//    }
//
////    func addClass(_ class: Class) throws {
////        try dbQueue.write { db in
////            try `class`.insert(db)
////        }
////    }
//
//    // Eine Klasse aktualisieren
//    func updateClass(_ class: Class) throws {
//        try dbQueue.write { db in
//            try `class`.update(db)
//        }
//    }
//
//    // Eine Klasse löschen
//    func deleteClass(id: UUID) throws {
//        try dbQueue.write { db in
//            try Class.filter(Class.Columns.id == id.uuidString).deleteAll(db)
//        }
//    }
//}
