import Foundation
import GRDB

class RatingRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getAllRatings() -> [Rating] {
        do {
            return try dbQueue.read { db in
                try Rating.fetchAll(db)
            }
        } catch {
            print("Fehler beim Laden der Bewertungen: \(error)")
            return []
        }
    }

    func addRating(_ rating: Rating) throws {
        try dbQueue.write { db in
            try rating.insert(db)
        }
    }

    func updateRating(_ rating: Rating) throws {
        try dbQueue.write { db in
            try rating.update(db)
        }
    }

    func deleteRating(id: UUID) throws {
        try dbQueue.write { db in
            try Rating.filter(Rating.Columns.id == id.uuidString).deleteAll(db)
        }
    }
}
