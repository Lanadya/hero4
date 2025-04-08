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

    @discardableResult
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
    
    @discardableResult
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
    
    @discardableResult
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

    @discardableResult
    func addRating(_ rating: Rating) -> Rating? {
        do {
            let _ = try dbQueue.write { db in
                try rating.insert(db)
            }
            return rating
        } catch {
            print("Fehler beim Hinzufügen der Bewertung: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateRating(_ rating: Rating) -> Rating? {
        do {
            let _ = try dbQueue.write { db in
                try rating.update(db)
            }
            return rating
        } catch {
            print("Fehler beim Aktualisieren der Bewertung: \(error)")
            return nil
        }
    }

    @discardableResult
    func deleteRating(id: UUID) -> Bool {
        do {
            let result = try dbQueue.write { db in
                try Rating.filter(Rating.Columns.id == id.uuidString).deleteAll(db)
            }
            print("Löschvorgang: \(result) Einträge entfernt")
            return true
        } catch {
            print("Fehler beim Löschen der Bewertung: \(error)")
            return false
        }
    }
    
    @discardableResult
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