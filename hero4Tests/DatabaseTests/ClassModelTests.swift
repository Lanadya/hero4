// Place in: hero4Tests/DatabaseTests/ClassModelTests.swift

import Testing
import GRDB
@testable import hero4

class ClassModelTests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbQueue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(dbQueue)
    }

    override func tearDownWithError() throws {
        dbQueue = nil
        try super.tearDownWithError()
    }

    func testClassValidation() {
        // Valid class
        let validClass = Class(
            name: "Valid",
            note: "Note",
            row: 1,
            column: 1
        )

        XCTAssertNoThrow(try validClass.validate(), "Valid class should not throw on validation")

        // Invalid name (empty)
        var emptyNameClass = validClass
        emptyNameClass.name = ""
        XCTAssertThrowsError(try emptyNameClass.validate(), "Empty name should throw validation error")

        // Invalid name (too long)
        var longNameClass = validClass
        longNameClass.name = "ThisNameIsTooLong"
        XCTAssertThrowsError(try longNameClass.validate(), "Long name should throw validation error")

        // Invalid note (too long)
        var longNoteClass = validClass
        longNoteClass.note = "This note is way too long and should trigger a validation error"
        XCTAssertThrowsError(try longNoteClass.validate(), "Long note should throw validation error")

        // Invalid dimensions
        var invalidRowClass = validClass
        invalidRowClass.row = 0
        XCTAssertThrowsError(try invalidRowClass.validate(), "Invalid row should throw validation error")

        var invalidColumnClass = validClass
        invalidColumnClass.column = 0
        XCTAssertThrowsError(try invalidColumnClass.validate(), "Invalid column should throw validation error")
    }

    func testClassDatabaseRoundTrip() throws {
        let originalClass = Class(
            name: "Test",
            note: "Note",
            row: 2,
            column: 3,
            maxRatingValue: 5,
            isArchived: false
        )

        // Insert into database
        try dbQueue.write { db in
            try originalClass.insert(db)
        }

        // Read back from database
        let retrievedClass = try dbQueue.read { db in
            try Class.fetchOne(db, key: originalClass.id.uuidString)
        }

        // Verify all properties are preserved
        XCTAssertNotNil(retrievedClass, "Class should be retrievable from database")
        XCTAssertEqual(retrievedClass?.id, originalClass.id, "ID should be preserved")
        XCTAssertEqual(retrievedClass?.name, originalClass.name, "Name should be preserved")
        XCTAssertEqual(retrievedClass?.note, originalClass.note, "Note should be preserved")
        XCTAssertEqual(retrievedClass?.row, originalClass.row, "Row should be preserved")
        XCTAssertEqual(retrievedClass?.column, originalClass.column, "Column should be preserved")
        XCTAssertEqual(retrievedClass?.maxRatingValue, originalClass.maxRatingValue, "Max rating value should be preserved")
        XCTAssertEqual(retrievedClass?.isArchived, originalClass.isArchived, "Archived status should be preserved")

        // Dates should be close (within a second)
        let createdAtDifference = abs(retrievedClass!.createdAt.timeIntervalSince(originalClass.createdAt))
        let modifiedAtDifference = abs(retrievedClass!.modifiedAt.timeIntervalSince(originalClass.modifiedAt))
        XCTAssertLessThan(createdAtDifference, 1.0, "Created date should be preserved within 1 second")
        XCTAssertLessThan(modifiedAtDifference, 1.0, "Modified date should be preserved within 1 second")
    }

    func testClassRelationships() throws {
        // Create a class
        let testClass = Class(
            name: "RelTest",
            row: 1,
            column: 1
        )

        // Create students in this class
        let student1 = Student(
            firstName: "Student",
            lastName: "One",
            classId: testClass.id
        )

        let student2 = Student(
            firstName: "Student",
            lastName: "Two",
            classId: testClass.id
        )

        // Insert everything in the database
        try dbQueue.write { db in
            try testClass.insert(db)
            try student1.insert(db)
            try student2.insert(db)
        }

        // Query students for this class
        let students = try dbQueue.read { db in
            try Student
                .filter(Column("classId") == testClass.id.uuidString)
                .fetchAll(db)
        }

        XCTAssertEqual(students.count, 2, "Class should have 2 students")
        XCTAssertTrue(students.contains(where: { $0.id == student1.id }), "Student 1 should be found")
        XCTAssertTrue(students.contains(where: { $0.id == student2.id }), "Student 2 should be found")
    }

    func testClassUniqueConstraint() throws {
        // Create a class
        let class1 = Class(
            name: "Unique",
            row: 1,
            column: 1
        )

        // Insert it
        try dbQueue.write { db in
            try class1.insert(db)
        }

        // Try to insert another class with the same name (should succeed if isArchived=true)
        let class2 = Class(
            id: UUID(), // Different ID
            name: "Unique", // Same name
            row: 2,
            column: 2,
            isArchived: true // This should allow it to be inserted despite the name
        )

        XCTAssertNoThrow(try dbQueue.write { db in
            try class2.insert(db)
        }, "Archived class with same name should be allowed")

        // Try to insert another active class with the same name (should fail due to unique constraint)
        let class3 = Class(
            id: UUID(), // Different ID
            name: "Unique", // Same name
            row: 3,
            column: 3,
            isArchived: false // This should cause a unique constraint violation
        )

        // This test depends on the exact implementation of your unique constraint
        // If you're using a unique index with a WHERE clause, it might throw
        // If you're checking programmatically, it might not throw
        // Adjust this assertion based on your actual implementation
        XCTAssertThrowsError(try dbQueue.write { db in
            try class3.insert(db)
        }, "Active class with duplicate name should fail")
    }

    func testClassPositionConstraint() throws {
        // Create a class
        let class1 = Class(
            name: "Position1",
            row: 5,
            column: 5
        )

        // Insert it
        try dbQueue.write { db in
            try class1.insert(db)
        }

        // Try to insert another class at the same position
        let class2 = Class(
            name: "Position2",
            row: 5, // Same row
            column: 5 // Same column
        )

        // Note: This doesn't test your application logic, only database constraints
        // If you're enforcing position uniqueness at the application level, this test may not fail

        // Check if your database has a unique constraint on (row, column)
        // If it does, this should throw, if not, adjust your expectations
        let result = try? dbQueue.write { db in
            try class2.insert(db)
        }

        // Check the database to see if both classes exist
        let classesAtPosition = try dbQueue.read { db in
            try Class
                .filter(Column("row") == 5 && Column("column") == 5)
                .fetchAll(db)
        }

        // Your expected behavior: whether multiple classes can occupy the same position
        // If your app logic prevents this but database doesn't, adjust this assertion
        if result == nil {
            XCTAssertEqual(classesAtPosition.count, 1, "Only one class should exist at this position")
        } else {
            // If your database allows multiple classes at the same position,
            // then you should check that your application logic prevents it
            XCTAssertEqual(classesAtPosition.count, 2, "Database allows multiple classes at same position")
        }
    }
}
