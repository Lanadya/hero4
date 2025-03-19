//
//  Class.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//

import Foundation


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
    }

    enum ValidationError: Error {
        case invalidName
        case invalidNote
    }
}
