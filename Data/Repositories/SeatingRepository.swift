import Foundation
import GRDB

class SeatingRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getAllSeatingPositions() -> [SeatingPosition] {
        do {
            return try dbQueue.read { db in
                try SeatingPosition.fetchAll(db)
            }
        } catch {
            print("Error loading seating positions: \(error)")
            return []
        }
    }

    func getSeatingPosition(id: UUID) -> SeatingPosition? {
        do {
            return try dbQueue.read { db in
                try SeatingPosition.filter(Column("id") == id.uuidString).fetchOne(db)
            }
        } catch {
            print("Error loading seating position: \(error)")
            return nil
        }
    }

    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition] {
        do {
            return try dbQueue.read { db in
                try SeatingPosition.filter(Column("classId") == classId.uuidString).fetchAll(db)
            }
        } catch {
            print("Error loading seating positions for class: \(error)")
            return []
        }
    }

    func addSeatingPosition(_ position: SeatingPosition) throws {
        try dbQueue.write { db in
            try position.insert(db)
        }
    }

    func updateSeatingPosition(_ position: SeatingPosition) throws {
        try dbQueue.write { db in
            try position.update(db)
        }
    }

    func deleteSeatingPosition(id: UUID) throws {
        try dbQueue.write { db in
            try SeatingPosition.filter(Column("id") == id.uuidString).deleteAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try SeatingPosition.deleteAll(db)
        }
    }
}
