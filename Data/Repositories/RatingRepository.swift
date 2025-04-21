import Foundation
import GRDB

/// Protokoll für RatingRepository
protocol RatingRepositoryProtocol {
    func getRatings() -> [Rating]
    func getRatingsForStudent(studentId: UUID) -> [Rating]
    func getRatingsForClass(classId: UUID, includeArchived: Bool) -> [Rating]
    func addRating(_ rating: Rating) -> Rating?
    func updateRating(_ rating: Rating) -> Rating?
    func deleteRating(id: UUID) -> Bool
    func getRating(id: UUID) -> Rating?
}

class GRDBRatingRepository: RatingRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func getRatings() -> [Rating] {
        do {
            return try dbQueue.read { db in
                try Rating.fetchAll(db)
            }
        } catch {
            print("Fehler beim Laden der Bewertungen: \(error)")
            return []
        }
    }
    
    func getRatingsForStudent(studentId: UUID) -> [Rating] {
        do {
            return try dbQueue.read { db in
                try Rating
                    .filter(Rating.Columns.studentId == studentId.uuidString)
                    .filter(Rating.Columns.isArchived == false)
                    .fetchAll(db)
            }
        } catch {
            print("Fehler beim Laden der Bewertungen für den Studenten: \(error)")
            return []
        }
    }
    
    func getRatingsForClass(classId: UUID, includeArchived: Bool = false) -> [Rating] {
        do {
            return try dbQueue.read { db in
                var query = Rating.filter(Rating.Columns.classId == classId.uuidString)
                
                if !includeArchived {
                    query = query.filter(Rating.Columns.isArchived == false)
                }
                
                return try query.fetchAll(db)
            }
        } catch {
            print("Fehler beim Laden der Bewertungen für die Klasse: \(error)")
            return []
        }
    }

    func addRating(_ rating: Rating) -> Rating? {
        do {
            var newRating = rating
            try dbQueue.write { db in
                try newRating.insert(db)
            }
            return newRating
        } catch {
            print("Fehler beim Hinzufügen der Bewertung: \(error)")
            return nil
        }
    }

    func updateRating(_ rating: Rating) -> Rating? {
        do {
            var updatedRating = rating
            try dbQueue.write { db in
                try updatedRating.update(db)
            }
            return updatedRating
        } catch {
            print("Fehler beim Aktualisieren der Bewertung: \(error)")
            return nil
        }
    }

    func deleteRating(id: UUID) -> Bool {
        do {
            try dbQueue.write { db in
                try Rating.filter(Rating.Columns.id == id.uuidString).deleteAll(db)
            }
            return true
        } catch {
            print("Fehler beim Löschen der Bewertung: \(error)")
            return false
        }
    }
    
    func getRating(id: UUID) -> Rating? {
        do {
            return try dbQueue.read { db in
                try Rating.filter(Rating.Columns.id == id.uuidString).fetchOne(db)
            }
        } catch {
            print("Fehler beim Laden der Bewertung: \(error)")
            return nil
        }
    }
}