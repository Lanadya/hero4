import Foundation
import GRDB

/// Protokoll für SeatingRepository
protocol SeatingRepositoryProtocol {
    func getSeatingPositions() -> [SeatingPosition]
    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition]
    func getSeatingPosition(studentId: UUID, classId: UUID) -> SeatingPosition?
    func addSeatingPosition(_ position: SeatingPosition) -> SeatingPosition?
    func updateSeatingPosition(_ position: SeatingPosition) -> SeatingPosition?
    func deleteSeatingPosition(id: UUID) -> Bool
    func arrangeSeatingGrid(classId: UUID, columns: Int) -> Bool
}

class GRDBSeatingRepository: SeatingRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getSeatingPositions() -> [SeatingPosition] {
        do {
            return try dbQueue.read { db in
                try SeatingPosition.fetchAll(db)
            }
        } catch {
            print("Error loading seating positions: \(error)")
            return []
        }
    }

    func getSeatingPosition(studentId: UUID, classId: UUID) -> SeatingPosition? {
        do {
            return try dbQueue.read { db in
                try SeatingPosition
                    .filter(SeatingPosition.Columns.studentId == studentId.uuidString)
                    .filter(SeatingPosition.Columns.classId == classId.uuidString)
                    .fetchOne(db)
            }
        } catch {
            print("Error loading seating position: \(error)")
            return nil
        }
    }

    func getSeatingPositionsForClass(classId: UUID) -> [SeatingPosition] {
        do {
            return try dbQueue.read { db in
                try SeatingPosition.filter(SeatingPosition.Columns.classId == classId.uuidString).fetchAll(db)
            }
        } catch {
            print("Error loading seating positions for class: \(error)")
            return []
        }
    }

    func addSeatingPosition(_ position: SeatingPosition) -> SeatingPosition? {
        do {
            var newPosition = position
            try dbQueue.write { db in
                try newPosition.save(db)
            }
            return newPosition
        } catch {
            print("Error adding seating position: \(error)")
            return nil
        }
    }

    func updateSeatingPosition(_ position: SeatingPosition) -> SeatingPosition? {
        do {
            var updatedPosition = position
            try dbQueue.write { db in
                try updatedPosition.update(db)
            }
            return updatedPosition
        } catch {
            print("Error updating seating position: \(error)")
            return nil
        }
    }

    func deleteSeatingPosition(id: UUID) -> Bool {
        do {
            try dbQueue.write { db in
                try SeatingPosition.filter(SeatingPosition.Columns.id == id.uuidString).deleteAll(db)
            }
            return true
        } catch {
            print("Error deleting seating position: \(error)")
            return false
        }
    }
    
    func arrangeSeatingGrid(classId: UUID, columns: Int) -> Bool {
        // Diese Funktion sollte im Kontext der direkten GRDB-Implementierung implementiert werden
        // Da sie Geschäftslogik enthält, ist sie besser in einem Service oder Manager
        print("Error: arrangeSeatingGrid ist nicht für die direkte GRDB-Implementierung verfügbar")
        return false
    }
}