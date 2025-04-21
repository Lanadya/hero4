import GRDB
import Foundation

/// Protokoll für ClassRepository
protocol ClassRepositoryProtocol {
    func getClasses() -> [Class]
    func addClass(_ classObj: Class) -> Class?
    func updateClass(_ classObj: Class) -> Class?
    func deleteClass(id: UUID) -> Bool
    func getClass(id: UUID) -> Class?
    func getClassAt(row: Int, column: Int) -> Class?
    func archiveClass(_ classObj: Class) -> Bool
}

// Implementierung für direkten GRDB-Zugriff
class GRDBClassRepository: ClassRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getClasses() -> [Class] {
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

    func addClass(_ classObj: Class) -> Class? {
        do {
            var newClass = classObj
            try dbQueue.write { db in
                try newClass.save(db)
            }
            return newClass
        } catch {
            print("Fehler beim Hinzufügen der Klasse: \(error)")
            return nil
        }
    }

    func updateClass(_ classObj: Class) -> Class? {
        do {
            var updatedClass = classObj
            try dbQueue.write { db in
                try updatedClass.update(db)
            }
            return updatedClass
        } catch {
            print("Fehler beim Aktualisieren der Klasse: \(error)")
            return nil
        }
    }

    func deleteClass(id: UUID) -> Bool {
        do {
            try dbQueue.write { db in
                try Class.filter(Column("id") == id.uuidString).deleteAll(db)
            }
            return true
        } catch {
            print("Fehler beim Löschen der Klasse: \(error)")
            return false
        }
    }
    
    func archiveClass(_ classObj: Class) -> Bool {
        var archivedClass = classObj
        archivedClass.isArchived = true
        return updateClass(archivedClass) != nil
    }
}

// Auskommentierter Duplikatcode wurde entfernt zur Verbesserung der Code-Wartbarkeit