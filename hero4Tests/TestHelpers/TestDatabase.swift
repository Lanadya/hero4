// Place in: hero4Tests/TestHelpers/TestDatabase.swift

import Testing
import GRDB
@testable import hero4

class TestDatabase {

    // In-memory database for isolated testing
    let dbQueue: DatabaseQueue

    // A data store instance configured for testing
    let dataStore: DataStore

    init() throws {
        // Create an in-memory database
        dbQueue = try DatabaseQueue()

        // Apply migrations to set up the schema
        try AppDatabase.migrator.migrate(dbQueue)

        // Create DataStore with this test database
        dataStore = DataStore.shared

        // Reset the DataStore to use our test database
        dataStore.resetForTesting(with: dbQueue)
    }

    // Add some sample data for testing
    func setupSampleData() throws {
        // Add a test class
        let testClass = Class(
            id: UUID(),
            name: "TestClass",
            note: "For Testing",
            row: 1,
            column: 1
        )
        dataStore.addClass(testClass)

        // Add a test student
        let testStudent = Student(
            id: UUID(),
            firstName: "Test",
            lastName: "Student",
            classId: testClass.id
        )
        dataStore.addStudent(testStudent)

        // Add a test seating position
        let testPosition = SeatingPosition(
            id: UUID(),
            studentId: testStudent.id,
            classId: testClass.id,
            xPos: 1,
            yPos: 1
        )
        dataStore.seatingPositions.append(testPosition)

        // Add a test rating
        let testRating = Rating(
            id: UUID(),
            studentId: testStudent.id,
            classId: testClass.id,
            date: Date(),
            value: .plus,
            schoolYear: "2024/2025"
        )
        dataStore.addRating(testRating)
    }

    // Clean up the database between tests
    func reset() throws {
        try dbQueue.write { db in
            try Class.deleteAll(db)
            try Student.deleteAll(db)
            try SeatingPosition.deleteAll(db)
            try Rating.deleteAll(db)
        }

        // Reset in-memory collections
        dataStore.classes = []
        dataStore.students = []
        dataStore.seatingPositions = []
        dataStore.ratings = []
    }
}


