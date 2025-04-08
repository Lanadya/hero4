//
//  Student.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//


import Foundation
import GRDB

struct Student: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var firstName: String
    var lastName: String
    var classId: UUID
    var entryDate: Date
    var exitDate: Date?
    var isArchived: Bool
    var notes: String?

    init(id: UUID = UUID(),
         firstName: String,
         lastName: String,
         classId: UUID,
         entryDate: Date = Date(),
         exitDate: Date? = nil,
         isArchived: Bool = false,
         notes: String? = nil) {

        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.classId = classId
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.isArchived = isArchived
        self.notes = notes
    }

    var fullName: String {
        if firstName.isEmpty {
            return lastName
        } else if lastName.isEmpty {
            return firstName
        } else {
            return "\(firstName) \(lastName)"
        }
    }

    var sortableName: String {
        if lastName.isEmpty {
            return firstName
        } else {
            return "\(lastName), \(firstName)"
        }
    }

    // Validierungen
    func validate() throws {
        if firstName.isEmpty && lastName.isEmpty {
            throw ValidationError.noName
        }
    }

    enum ValidationError: Error {
        case noName
    }
}

// MARK: - GRDB Record Protocols
extension Student: TableRecord, FetchableRecord, PersistableRecord {
    // Define table name
    static var databaseTableName: String { "student" }

    // Define column names
    enum Columns {
        static let id = Column("id")
        static let firstName = Column("firstName")
        static let lastName = Column("lastName")
        static let classId = Column("classId")
        static let entryDate = Column("entryDate")
        static let exitDate = Column("exitDate")
        static let isArchived = Column("isArchived")
        static let notes = Column("notes")
    }

    // Encode the Student to database columns
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.firstName] = firstName
        container[Columns.lastName] = lastName
        container[Columns.classId] = classId.uuidString
        container[Columns.entryDate] = entryDate
        container[Columns.exitDate] = exitDate
        container[Columns.isArchived] = isArchived
        container[Columns.notes] = notes
    }

    // Initialize Student from database row
    init(row: Row) {
        self.id = UUID(uuidString: row[Columns.id]) ?? UUID()
        self.firstName = row[Columns.firstName]
        self.lastName = row[Columns.lastName]
        self.classId = UUID(uuidString: row[Columns.classId]) ?? UUID()
        self.entryDate = row[Columns.entryDate]
        self.exitDate = row[Columns.exitDate]
        self.isArchived = row[Columns.isArchived]
        self.notes = row[Columns.notes]
    }
}
