import Foundation
import GRDB

/// Zentrale Datenbankklasse für die App
struct AppDatabase {
    /// Gemeinsame Datenbankinstanz für die App
    static let shared = makeShared()

    /// Die zugrunde liegende Datenbankverbindung
    private let dbWriter: DatabaseWriter

    /// Initialisiert eine Datenbankverbindung
    private init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    /// Erstellt und konfiguriert eine neue Datenbankverbindung
    private static func makeShared() -> AppDatabase {
        do {
            // Datenbankdatei im Dokumentenverzeichnis
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = folderURL.appendingPathComponent("gradeHero.sqlite")

            // Datenbankverbindung öffnen
            let dbPool = try DatabasePool(path: dbURL.path)

            // Migrationen anwenden
            try migrator.migrate(dbPool)

            return AppDatabase(dbWriter: dbPool)
        } catch {
            // Im Fehlerfall erstelle eine In-Memory-Datenbank
            NSLog("FEHLER: Konnte Datenbank nicht konfigurieren - verwende stattdessen In-Memory-DB: \(error)")
            do {
                let dbQueue = try DatabaseQueue()
                try migrator.migrate(dbQueue)
                return AppDatabase(dbWriter: dbQueue)
            } catch {
                fatalError("KRITISCHER FEHLER: Konnte keine Datenbank erstellen: \(error)")
            }
        }
    }

    /// Datenbank-Migrator mit allen Migrationsschritten
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Initialmigration - erstellt die Tabellen
        migrator.registerMigration("createInitialSchema") { db in
            // Erstelle die Tabellen
            try createClassTable(db)
            try createStudentTable(db)
            try createSeatingPositionTable(db)
            try createRatingTable(db)
        }

        return migrator
    }

    // Tabellendefinitionen
    private static func createClassTable(_ db: Database) throws {
        try db.create(table: "class") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("note", .text)
            t.column("row", .integer).notNull()
            t.column("column", .integer).notNull()
            t.column("maxRatingValue", .integer).notNull().defaults(to: 4)
            t.column("isArchived", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull()
            t.column("modifiedAt", .datetime).notNull()
        }

        // Indizes separat erstellen
        try db.execute(sql: "CREATE INDEX class_row_column_idx ON class(row, column)")
        try db.execute(sql: "CREATE UNIQUE INDEX class_name_idx ON class(name) WHERE isArchived = 0")
    }

    private static func createStudentTable(_ db: Database) throws {
        try db.create(table: "student") { t in
            t.column("id", .text).primaryKey()
            t.column("firstName", .text).notNull()
            t.column("lastName", .text).notNull()
            t.column("classId", .text)
                .notNull()
                .references("class", onDelete: .cascade)
            t.column("entryDate", .datetime).notNull()
            t.column("exitDate", .datetime)
            t.column("isArchived", .boolean).notNull().defaults(to: false)
            t.column("notes", .text)
        }

        // Indizes separat erstellen
        try db.execute(sql: "CREATE INDEX student_classId_idx ON student(classId)")
        try db.execute(sql: "CREATE INDEX student_names_idx ON student(firstName, lastName, classId)")
    }

    private static func createSeatingPositionTable(_ db: Database) throws {
        try db.create(table: "seatingPosition") { t in
            t.column("id", .text).primaryKey()
            t.column("studentId", .text)
                .notNull()
                .references("student", onDelete: .cascade)
            t.column("classId", .text)
                .notNull()
                .references("class", onDelete: .cascade)
            t.column("xPos", .integer).notNull()
            t.column("yPos", .integer).notNull()
            t.column("lastUpdated", .datetime).notNull()
            t.column("isCustomPosition", .boolean).notNull().defaults(to: false)
        }

        // Indizes und Unique Constraint separat erstellen
        try db.execute(sql: "CREATE INDEX seatingPosition_studentId_idx ON seatingPosition(studentId)")
        try db.execute(sql: "CREATE INDEX seatingPosition_classId_idx ON seatingPosition(classId)")
        try db.execute(sql: "CREATE UNIQUE INDEX seatingPosition_student_class_idx ON seatingPosition(studentId, classId)")
    }

    private static func createRatingTable(_ db: Database) throws {
        try db.create(table: "rating") { t in
            t.column("id", .text).primaryKey()
            t.column("studentId", .text)
                .notNull()
                .references("student", onDelete: .cascade)
            t.column("classId", .text)
                .notNull()
                .references("class", onDelete: .cascade)
            t.column("date", .datetime).notNull()
            t.column("value", .integer)
            t.column("isAbsent", .boolean).notNull().defaults(to: false)
            t.column("isArchived", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull()
            t.column("schoolYear", .text).notNull()
        }

        // Indizes separat erstellen
        try db.execute(sql: "CREATE INDEX rating_studentId_idx ON rating(studentId)")
        try db.execute(sql: "CREATE INDEX rating_classId_idx ON rating(classId)")
        try db.execute(sql: "CREATE INDEX rating_date_idx ON rating(date)")
        try db.execute(sql: "CREATE INDEX rating_composite_idx ON rating(studentId, classId, date)")
    }

    /// Ausführung einer Datenbanktransaktion
    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbWriter.write(updates)
    }

    /// Ausführung einer Datenbankabfrage
    func read<T>(_ value: (Database) throws -> T) throws -> T {
        try dbWriter.read(value)
    }
}
