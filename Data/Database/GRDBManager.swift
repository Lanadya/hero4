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

    func fetchClasses() throws -> [Class] {
        try AppDatabase.shared.read { db in
            // Alle Klassen abfragen, sortiert nach Zeile und Spalte
            let classes = try Class
                .order(Class.Columns.row.asc, Class.Columns.column.asc)
                .fetchAll(db)

            return classes
        }
    }

    func fetchClass(id: UUID) throws -> Class? {
        try AppDatabase.shared.read { db in
            try Class
                .filter(Class.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

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

    func deleteClass(id: UUID) throws {
        try AppDatabase.shared.write { db in
            _ = try Class
                .filter(Class.Columns.id == id.uuidString)
                .deleteAll(db)
        }
    }

    // MARK: - Student CRUD-Operationen

    func saveStudent(_ student: Student) throws -> Student {
        try AppDatabase.shared.write { db in
            try student.save(db)
        }
        return student
    }

    func fetchStudents() throws -> [Student] {
        try AppDatabase.shared.read { db in
            try Student.fetchAll(db)
        }
    }

    func fetchStudent(id: UUID) throws -> Student? {
        try AppDatabase.shared.read { db in
            try Student
                .filter(Student.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

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

    func deleteStudent(id: UUID) throws {
        try AppDatabase.shared.write { db in
            _ = try Student
                .filter(Student.Columns.id == id.uuidString)
                .deleteAll(db)
        }
    }

    // MARK: - SeatingPosition CRUD-Operationen

    func saveSeatingPosition(_ position: SeatingPosition) throws -> SeatingPosition {
        try AppDatabase.shared.write { db in
            try position.save(db)
        }
        return position
    }

    func fetchSeatingPositions() throws -> [SeatingPosition] {
        try AppDatabase.shared.read { db in
            try SeatingPosition.fetchAll(db)
        }
    }

    func fetchSeatingPosition(id: UUID) throws -> SeatingPosition? {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    func fetchSeatingPositionsForClass(classId: UUID) throws -> [SeatingPosition] {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.classId == classId.uuidString)
                .fetchAll(db)
        }
    }

    func fetchSeatingPositionForStudent(studentId: UUID, classId: UUID) throws -> SeatingPosition? {
        try AppDatabase.shared.read { db in
            try SeatingPosition
                .filter(SeatingPosition.Columns.studentId == studentId.uuidString)
                .filter(SeatingPosition.Columns.classId == classId.uuidString)
                .fetchOne(db)
        }
    }

    func deleteSeatingPosition(id: UUID) throws {
        try AppDatabase.shared.write { db in
            _ = try SeatingPosition
                .filter(SeatingPosition.Columns.id == id.uuidString)
                .deleteAll(db)
        }
    }

    // MARK: - Rating CRUD-Operationen

    func saveRating(_ rating: Rating) throws -> Rating {
        try AppDatabase.shared.write { db in
            try rating.save(db)
        }
        return rating
    }

    func fetchRatings() throws -> [Rating] {
        try AppDatabase.shared.read { db in
            try Rating.fetchAll(db)
        }
    }

    func fetchRating(id: UUID) throws -> Rating? {
        try AppDatabase.shared.read { db in
            try Rating
                .filter(Rating.Columns.id == id.uuidString)
                .fetchOne(db)
        }
    }

    func fetchRatingsForStudent(studentId: UUID) throws -> [Rating] {
        try AppDatabase.shared.read { db in
            try Rating
                .filter(Rating.Columns.studentId == studentId.uuidString)
                .filter(Rating.Columns.isArchived == false)
                .fetchAll(db)
        }
    }

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

    func deleteRating(id: UUID) throws {
        try AppDatabase.shared.write { db in
            _ = try Rating
                .filter(Rating.Columns.id == id.uuidString)
                .deleteAll(db)
        }
    }

    // MARK: - Migration von UserDefaults

    func migrateClassesFromUserDefaults() throws {
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
        } else {
            print("DEBUG GRDBManager: Keine Klassen in UserDefaults gefunden")
        }
    }

    func migrateStudentsFromUserDefaults() throws {
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
        } else {
            print("DEBUG GRDBManager: Keine Studenten in UserDefaults gefunden")
        }
    }

    func migrateSeatingPositionsFromUserDefaults() throws {
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
        } else {
            print("DEBUG GRDBManager: Keine Sitzpositionen in UserDefaults gefunden")
        }
    }

    func migrateRatingsFromUserDefaults() throws {
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
        } else {
            print("DEBUG GRDBManager: Keine Bewertungen in UserDefaults gefunden")
        }
    }

    func migrateAllDataFromUserDefaults() throws {
        try migrateClassesFromUserDefaults()
        try migrateStudentsFromUserDefaults()
        try migrateSeatingPositionsFromUserDefaults()
        try migrateRatingsFromUserDefaults()

        print("DEBUG GRDBManager: Migration aller Daten von UserDefaults abgeschlossen")
    }
}
