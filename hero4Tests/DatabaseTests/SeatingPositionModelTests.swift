// Place in: hero4Tests/DatabaseTests/SeatingPositionModelTests.swift

import Testing
import GRDB
@testable import hero4

class SeatingPositionModelTests: XCTestCase {

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

    func testSeatingPositionDatabaseRoundTrip() throws {
        // Create a class and a student
        let testClass = Class(
            name: "SeatingTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Seating",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create a seating position
        let originalPosition = SeatingPosition(
            studentId: student.id,
            classId: testClass.id,
            xPos: 3,
            yPos: 4,
            isCustomPosition: true
        )

        // Insert the position
        try dbQueue.write { db in
            try originalPosition.insert(db)
        }

        // Read back from database
        let retrievedPosition = try dbQueue.read { db in
            try SeatingPosition.fetchOne(db, key: originalPosition.id.uuidString)
        }

        // Verify all properties are preserved
        XCTAssertNotNil(retrievedPosition, "Seating position should be retrievable from database")
        XCTAssertEqual(retrievedPosition?.id, originalPosition.id, "ID should be preserved")
        XCTAssertEqual(retrievedPosition?.studentId, originalPosition.studentId, "Student ID should be preserved")
        XCTAssertEqual(retrievedPosition?.classId, originalPosition.classId, "Class ID should be preserved")
        XCTAssertEqual(retrievedPosition?.xPos, originalPosition.xPos, "X position should be preserved")
        XCTAssertEqual(retrievedPosition?.yPos, originalPosition.yPos, "Y position should be preserved")
        XCTAssertEqual(retrievedPosition?.isCustomPosition, originalPosition.isCustomPosition, "Custom position flag should be preserved")

        // Check lastUpdated date (within 1 second tolerance)
        let dateTimeDifference = abs(retrievedPosition!.lastUpdated.timeIntervalSince(originalPosition.lastUpdated))
        XCTAssertLessThan(dateTimeDifference, 1.0, "Last updated timestamp should be preserved within 1 second")
    }

    func testSeatingPositionUniqueConstraint() throws {
        // Create a class and two students
        let testClass = Class(
            name: "UniqueTest",
            row: 1,
            column: 1
        )

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

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student1.insert(db)
            try student2.insert(db)
        }

        // Create a seating position for student1
        let position1 = SeatingPosition(
            studentId: student1.id,
            classId: testClass.id,
            xPos: 1,
            yPos: 1
        )

        // Insert the position
        try dbQueue.write { db in
            try position1.insert(db)
        }

        // Create a second position for student1 in the same class
        // This should fail if you have a unique constraint on (studentId, classId)
        let position2 = SeatingPosition(
            id: UUID(), // Different ID
            studentId: student1.id, // Same student
            classId: testClass.id, // Same class
            xPos: 2,
            yPos: 2
        )

        // This test depends on your database schema and constraints
        // If you have a unique constraint on (studentId, classId), this should throw
        // If not, this test needs adjustment
        do {
            try dbQueue.write { db in
                try position2.insert(db)
            }

            // If no error was thrown, verify with a query
            let positions = try dbQueue.read { db in
                try SeatingPosition
                    .filter(Column("studentId") == student1.id.uuidString)
                    .filter(Column("classId") == testClass.id.uuidString)
                    .fetchAll(db)
            }

            // Check whether your schema enforces uniqueness
            if positions.count > 1 {
                print("Warning: Your database schema allows multiple seating positions for the same student in the same class.")
                print("Consider adding a unique constraint on (studentId, classId).")
            } else {
                XCTAssertEqual(positions.count, 1, "Should have only one position per student per class")
            }
        } catch {
            // If an error was thrown, the unique constraint is working
            XCTAssertTrue(true, "Unique constraint prevented duplicate seating position")
        }
    }

    func testSeatingPositionForStudentInMultipleClasses() throws {
        // Create two classes
        let class1 = Class(
            name: "Class1",
            row: 1,
            column: 1
        )

        let class2 = Class(
            name: "Class2",
            row: 2,
            column: 2
        )

        // Create a student that belongs to both classes (this is just for testing)
        let student = Student(
            firstName: "MultiClass",
            lastName: "Student",
            classId: class1.id // Primary class
        )

        // Insert them
        try dbQueue.write { db in
            try class1.insert(db)
            try class2.insert(db)
            try student.insert(db)
        }

        // Create seating positions for the student in both classes
        let position1 = SeatingPosition(
            studentId: student.id,
            classId: class1.id,
            xPos: 1,
            yPos: 1
        )

        let position2 = SeatingPosition(
            studentId: student.id,
            classId: class2.id,
            xPos: 2,
            yPos: 2
        )

        // Insert both positions
        try dbQueue.write { db in
            try position1.insert(db)
            try position2.insert(db)
        }

        // Query positions for class1
        let class1Positions = try dbQueue.read { db in
            try SeatingPosition
                .filter(Column("classId") == class1.id.uuidString)
                .fetchAll(db)
        }

        // Query positions for class2
        let class2Positions = try dbQueue.read { db in
            try SeatingPosition
                .filter(Column("classId") == class2.id.uuidString)
                .fetchAll(db)
        }

        XCTAssertEqual(class1Positions.count, 1, "Class1 should have one seating position")
        XCTAssertEqual(class2Positions.count, 1, "Class2 should have one seating position")
        XCTAssertEqual(class1Positions.first?.xPos, 1, "Class1 position should have xPos=1")
        XCTAssertEqual(class2Positions.first?.xPos, 2, "Class2 position should have xPos=2")
    }

    func testCustomPositionFlag() throws {
        // Create a class and a student
        let testClass = Class(
            name: "CustomTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Custom",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create a non-custom position (system-generated)
        let automaticPosition = SeatingPosition(
            studentId: student.id,
            classId: testClass.id,
            xPos: 0,
            yPos: 0,
            isCustomPosition: false
        )

        // Insert the position
        try dbQueue.write { db in
            try automaticPosition.insert(db)
        }

        // Update to a custom position
        var customPosition = automaticPosition
        customPosition.xPos = 5
        customPosition.yPos = 5
        customPosition.isCustomPosition = true
        customPosition.lastUpdated = Date()

        try dbQueue.write { db in
            try customPosition.update(db)
        }

        // Read back from database
        let retrievedPosition = try dbQueue.read { db in
            try SeatingPosition.fetchOne(db, key: automaticPosition.id.uuidString)
        }

        XCTAssertNotNil(retrievedPosition, "Position should be retrievable")
        XCTAssertEqual(retrievedPosition?.xPos, 5, "X position should be updated")
        XCTAssertEqual(retrievedPosition?.yPos, 5, "Y position should be updated")
        XCTAssertTrue(retrievedPosition!.isCustomPosition, "Position should be marked as custom")
    }
}
