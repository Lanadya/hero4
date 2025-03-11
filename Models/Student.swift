//
//  Student.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//


import Foundation

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
