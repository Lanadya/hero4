//
//  GRDBManager.swift
//  hero4
//
//  Created by Nina Klee on 26.03.25.
//

import Foundation
import GRDB

/// Manager-Klasse zur Integration von GRDB mit dem vorhandenen DataStore
class GRDBManager {
    static let shared = GRDBManager()

    private init() {}

    // MARK: - Class CRUD-Operationen

    @discardableResult
    func saveClass(_ appClass: Class) throws -> Class {
        // Aktualisiere modifiedAt, wenn es eine bestehende Klasse ist
        var updatedClass = appClass
        updatedClass.modifiedAt = Date()

        // In Datenbank speichern
        try AppDatabase.shared.write { db in
            try updatedClass.validate()
            try updatedClass.save(db)
        }

        return updatedClass
    }

    @discardableResult
    func fetchClasses() throws -> [Class] {
        try AppDatabase.shared.read { db in
            // Alle Klassen abfragen, sortiert nach Zeile und Spalte
            let classes = try Class
                .order(Class.Columns.row.asc, Class.Columns.column.asc)
                .fetchAll(db)

            return classes
        }
    }

    @discardableResult
    func fetchClass(id: UUID) throws -> Class? {
        try AppDatabase.shared.read { db in
            try Class
                .filter(Class.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    @discardableResult
    func fetchClassAt(row: Int, column: Int, includeArchived: Bool = false) throws -> Class? {
        try AppDatabase.shared.read { db in
            var query = Class
                .filter(Class.Columns.row == row)
                .filter(Class.Columns.column == column)

            if !includeArchived {
                query = query.filter(Class.Columns.isArchived == false)
            }

            return try query.fetchOne(db)
        }
    }

    @discardableResult
    func deleteClass(id: UUID) throws -> Bool {
        try AppDatabase.shared.write { db in
            try Class
                .filter(Class.Columns.id == id.uuidString)
                .deleteAll(db)
        }
        return true
    }

    // MARK: - Student CRUD-Operationen

    @discardableResult
    func saveStudent(_ student: Student) throws -> Student {
        try AppDatabase.shared.write { db in
            try student.save(db)
        }
        return student
    }

    @discardableResult
    func fetchStudents() throws -> [Student] {
        try AppDatabase.shared.read { db in
            try Student.fetchAll(db)
        }
    }

    @discardableResult
    func fetchStudent(id: UUID) throws -> Student? {
        try AppDatabase.shared.read { db in
            try Student
                .filter(Student.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    @discardableResult
    func fetchStudentsForClass(classId: UUID, includeArchived: Bool = false) throws -> [Student] {
        try AppDatabase.shared.read { db in
            var query = Student
                .filter(Student.Columns.classId == classId.uuidString)

            if !includeArchived {
                query = query.filter(Student.Columns.isArchived == false)
            }

            return try query.fetchAll(db)
        }
    }

    @discardableResult
    func deleteStudent(id: UUID) throws -> Bool {
        try AppDatabase.shared.write { db in
            try Student
                .filter(Student.Columns.id == id.uuidString)
                .deleteAll(db)
        }
        return true
    }

    // MARK: - SeatingPosition CRUD-Operationen

    @discardableResult
    func saveSeatingPosition(_ position: SeatingPosition) throws -> SeatingPosition {
        try AppDatabase.shared.write { db in
            try position.save(db)
        }
        return position
    }

    @discardableResult
    func fetchSeatingPositions() throws -> [SeatingPosition] {
        try AppDatabase.shared.read { db in
            try SeatingPosition.fetchAll(db)
        }
    }

    @discardableResult
    func fetchSeatingPosition(id: UUID) throws -> SeatingPosition? {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    @discardableResult
    func fetchSeatingPositionsForClass(classId: UUID) throws -> [SeatingPosition] {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.classId == classId.uuidString)
                .fetchAll(db)
        }
    }

    @discardableResult
    func fetchSeatingPositionForStudent(studentId: UUID, classId: UUID) throws -> SeatingPosition? {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.studentId == studentId.uuidString)
                .filter(SeatingPosition.Columns.classId == classId.uuidString)
                .fetchOne(db)
        }
    }

    @discardableResult
    func deleteSeatingPosition(id: UUID) throws -> Bool {
        try AppDatabase.shared.write { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.id == id.uuidString)
                .deleteAll(db)
        }
        return true
    }

    // MARK: - Rating CRUD-Operationen

    @discardableResult
    func saveRating(_ rating: Rating) throws -> Rating {
        try AppDatabase.shared.write { db in
            try rating.save(db)
        }
        return rating
    }

    @discardableResult
    func fetchRatings() throws -> [Rating] {
        try AppDatabase.shared.read { db in
            try Rating.fetchAll(db)
        }
    }

    @discardableResult
    func fetchRating(id: UUID) throws -> Rating? {
        try AppDatabase.shared.read { db in
            try Rating
                .filter(Rating.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    @discardableResult
    func fetchRatingsForStudent(studentId: UUID) throws -> [Rating] {
        try AppDatabase.shared.read { db in
            try Rating
                .filter(Rating.Columns.studentId == studentId.uuidString)
                .filter(Rating.Columns.isArchived == false)
                .fetchAll(db)
        }
    }

    @discardableResult
    func fetchRatingsForClass(classId: UUID, includeArchived: Bool = false) throws -> [Rating] {
        try AppDatabase.shared.read { db in
            var query = Rating
                .filter(Rating.Columns.classId == classId.uuidString)

            if !includeArchived {
                query = query.filter(Rating.Columns.isArchived == false)
            }

            return try query.fetchAll(db)
        }
    }

    @discardableResult
    func deleteRating(id: UUID) throws -> Bool {
        try AppDatabase.shared.write { db in
            try Rating
                .filter(Rating.Columns.id == id.uuidString)
                .deleteAll(db)
        }
        return true
    }

    // MARK: - Migration von UserDefaults

    @discardableResult
    func migrateClassesFromUserDefaults() throws -> Bool {
        // Lade Klassen aus UserDefaults
        if let data = UserDefaults.standard.data(forKey: "hero4_classes") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let classes = try decoder.decode([Class].self, from: data)

            // Speichere Klassen in GRDB
            try AppDatabase.shared.write { db in
                for appClass in classes {
                    try appClass.save(db)
                }
            }

            print("DEBUG GRDBManager: \(classes.count) Klassen von UserDefaults migriert")
            return true
        } else {
            print("DEBUG GRDBManager: Keine Klassen in UserDefaults gefunden")
            return false
        }
    }

    @discardableResult
    func migrateStudentsFromUserDefaults() throws -> Bool {
        if let data = UserDefaults.standard.data(forKey: "hero4_students") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let students = try decoder.decode([Student].self, from: data)

            try AppDatabase.shared.write { db in
                for student in students {
                    try student.save(db)
                }
            }

            print("DEBUG GRDBManager: \(students.count) Studenten von UserDefaults migriert")
            return true
        } else {
            print("DEBUG GRDBManager: Keine Studenten in UserDefaults gefunden")
            return false
        }
    }

    @discardableResult
    func migrateSeatingPositionsFromUserDefaults() throws -> Bool {
        if let data = UserDefaults.standard.data(forKey: "hero4_seating_positions") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let positions = try decoder.decode([SeatingPosition].self, from: data)

            try AppDatabase.shared.write { db in
                for position in positions {
                    try position.save(db)
                }
            }

            print("DEBUG GRDBManager: \(positions.count) Sitzpositionen von UserDefaults migriert")
            return true
        } else {
            print("DEBUG GRDBManager: Keine Sitzpositionen in UserDefaults gefunden")
            return false
        }
    }

    @discardableResult
    func migrateRatingsFromUserDefaults() throws -> Bool {
        if let data = UserDefaults.standard.data(forKey: "hero4_ratings") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let ratings = try decoder.decode([Rating].self, from: data)

            try AppDatabase.shared.write { db in
                for rating in ratings {
                    try rating.save(db)
                }
            }

            print("DEBUG GRDBManager: \(ratings.count) Bewertungen von UserDefaults migriert")
            return true
        } else {
            print("DEBUG GRDBManager: Keine Bewertungen in UserDefaults gefunden")
            return false
        }
    }

    @discardableResult
    func migrateAllDataFromUserDefaults() throws -> Bool {
        try migrateClassesFromUserDefaults()
        try migrateStudentsFromUserDefaults()
        try migrateSeatingPositionsFromUserDefaults()
        try migrateRatingsFromUserDefaults()

        print("DEBUG GRDBManager: Migration aller Daten von UserDefaults abgeschlossen")
        return true
    }
}
