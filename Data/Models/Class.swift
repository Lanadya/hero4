//
//  Class.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//

import Foundation
import GRDB

struct Class: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var note: String?
    var row: Int
    var column: Int
    var maxRatingValue: Int
    var isArchived: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(),
         name: String,
         note: String? = nil,
         row: Int,
         column: Int,
         maxRatingValue: Int = 4,
         isArchived: Bool = false,
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {

        self.id = id
        self.name = name
        self.note = note
        self.row = row
        self.column = column
        self.maxRatingValue = maxRatingValue
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // Validierungen
    func validate() throws {
        if name.isEmpty || name.count > 8 {
            throw ValidationError.invalidName
        }
        if let note = note, note.count > 10 {
            throw ValidationError.invalidNote
        }
        if row <= 0 || column <= 0 {
            throw ValidationError.invalidDimensions
        }
    }

    enum ValidationError: Error {
        case invalidName
        case invalidNote
        case invalidDimensions
    }
}

// MARK: - GRDB Record Protokolle
extension Class: TableRecord, FetchableRecord, PersistableRecord {
    // Tabellennamen definieren
    static var databaseTableName: String { "class" }

    // Spaltendefinitionen
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let note = Column("note")
        static let row = Column("row")
        static let column = Column("column")
        static let maxRatingValue = Column("maxRatingValue")
        static let isArchived = Column("isArchived")
        static let createdAt = Column("createdAt")
        static let modifiedAt = Column("modifiedAt")
    }

    // UUID als String in der Datenbank speichern
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.name] = name
        container[Columns.note] = note
        container[Columns.row] = row
        container[Columns.column] = column
        container[Columns.maxRatingValue] = maxRatingValue
        container[Columns.isArchived] = isArchived
        container[Columns.createdAt] = createdAt
        container[Columns.modifiedAt] = modifiedAt
    }

    // Beim Laden aus der Datenbank
    init(row dbRow: Row) {
        // Verbessertes Fehlerhandling ohne Fatal Error
        if let idString = dbRow[Columns.id] as? String,
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            NSLog("WARNUNG: Ungültige UUID in Datenbank: \(dbRow[Columns.id] ?? "nil"), verwende neue UUID")
            self.id = UUID() // Verwende neue UUID statt Absturz
        }
        
        self.name = dbRow[Columns.name]
        self.note = dbRow[Columns.note]
        self.row = dbRow[Columns.row]    // Jetzt eindeutig
        self.column = dbRow[Columns.column]
        self.maxRatingValue = dbRow[Columns.maxRatingValue]
        self.isArchived = dbRow[Columns.isArchived]
        self.createdAt = dbRow[Columns.createdAt]
        self.modifiedAt = dbRow[Columns.modifiedAt]
    }
}
