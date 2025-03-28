//
//  SeatingPosition.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//

import Foundation
import GRDB

struct SeatingPosition: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var xPos: Int
    var yPos: Int
    var lastUpdated: Date
    var isCustomPosition: Bool  // Zeigt an, ob die Position manuell gesetzt wurde

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         xPos: Int,
         yPos: Int,
         lastUpdated: Date = Date(),
         isCustomPosition: Bool = false) {

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.xPos = xPos
        self.yPos = yPos
        self.lastUpdated = lastUpdated
        self.isCustomPosition = isCustomPosition
    }
}

// MARK: - GRDB Record Protocols
extension SeatingPosition: TableRecord, FetchableRecord, PersistableRecord {
    // Define table name
    static var databaseTableName: String { "seatingPosition" }

    // Define column names
    enum Columns {
        static let id = Column("id")
        static let studentId = Column("studentId")
        static let classId = Column("classId")
        static let xPos = Column("xPos")
        static let yPos = Column("yPos")
        static let lastUpdated = Column("lastUpdated")
        static let isCustomPosition = Column("isCustomPosition")
    }

    // Encode the SeatingPosition to database columns
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.studentId] = studentId.uuidString
        container[Columns.classId] = classId.uuidString
        container[Columns.xPos] = xPos
        container[Columns.yPos] = yPos
        container[Columns.lastUpdated] = lastUpdated
        container[Columns.isCustomPosition] = isCustomPosition
    }

    // Initialize SeatingPosition from database row
    init(row: Row) {
        self.id = UUID(uuidString: row[Columns.id]) ?? UUID()
        self.studentId = UUID(uuidString: row[Columns.studentId]) ?? UUID()
        self.classId = UUID(uuidString: row[Columns.classId]) ?? UUID()
        self.xPos = row[Columns.xPos]
        self.yPos = row[Columns.yPos]
        self.lastUpdated = row[Columns.lastUpdated]
        self.isCustomPosition = row[Columns.isCustomPosition]
    }
}
