// Place in: hero4Tests/DatabaseTests/RatingModelTests.swift

import Testing
import GRDB
@testable import hero4

class RatingModelTests: XCTestCase {

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

    func testRatingValueProperties() {
        // Test string representation
        XCTAssertEqual(RatingValue.doublePlus.stringValue, "++", "Double plus should be '++'")
        XCTAssertEqual(RatingValue.plus.stringValue, "+", "Plus should be '+'")
        XCTAssertEqual(RatingValue.minus.stringValue, "-", "Minus should be '-'")
        XCTAssertEqual(RatingValue.doubleMinus.stringValue, "--", "Double minus should be '--'")

        // Test numeric representation
        XCTAssertEqual(RatingValue.doublePlus.numericValue, 1.0, "Double plus should be 1.0")
        XCTAssertEqual(RatingValue.plus.numericValue, 2.0, "Plus should be 2.0")
        XCTAssertEqual(RatingValue.minus.numericValue, 3.0, "Minus should be 3.0")
        XCTAssertEqual(RatingValue.doubleMinus.numericValue, 4.0, "Double minus should be 4.0")
    }

    func testRatingDatabaseRoundTrip() throws {
        // Create a class and a student
        let testClass = Class(
            name: "RatingTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Rating",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create a rating
        let originalRating = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: Date(),
            value: .plus,
            isAbsent: false,
            isArchived: false,
            schoolYear: "2024/2025"
        )

        // Insert the rating
        try dbQueue.write { db in
            try originalRating.insert(db)
        }

        // Read back from database
        let retrievedRating = try dbQueue.read { db in
            try Rating.fetchOne(db, key: originalRating.id.uuidString)
        }

        // Verify all properties are preserved
        XCTAssertNotNil(retrievedRating, "Rating should be retrievable from database")
        XCTAssertEqual(retrievedRating?.id, originalRating.id, "ID should be preserved")
        XCTAssertEqual(retrievedRating?.studentId, originalRating.studentId, "Student ID should be preserved")
        XCTAssertEqual(retrievedRating?.classId, originalRating.classId, "Class ID should be preserved")
        XCTAssertEqual(retrievedRating?.value, originalRating.value, "Rating value should be preserved")
        XCTAssertEqual(retrievedRating?.isAbsent, originalRating.isAbsent, "Absence status should be preserved")
        XCTAssertEqual(retrievedRating?.isArchived, originalRating.isArchived, "Archived status should be preserved")
        XCTAssertEqual(retrievedRating?.schoolYear, originalRating.schoolYear, "School year should be preserved")

        // Check dates (within 1 second tolerance)
        let dateDifference = abs(retrievedRating!.date.timeIntervalSince(originalRating.date))
        let createdAtDifference = abs(retrievedRating!.createdAt.timeIntervalSince(originalRating.createdAt))

        XCTAssertLessThan(dateDifference, 1.0, "Rating date should be preserved within 1 second")
        XCTAssertLessThan(createdAtDifference, 1.0, "Created date should be preserved within 1 second")
    }

    func testRatingAbsenceWithoutValue() throws {
        // Create a class and a student
        let testClass = Class(
            name: "AbsenceTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Absence",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create a rating for an absent student (no value)
        let absentRating = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: Date(),
            value: nil, // No rating value for absent student
            isAbsent: true,
            schoolYear: "2024/2025"
        )

        // Insert the rating
        try dbQueue.write { db in
            try absentRating.insert(db)
        }

        // Read back from database
        let retrievedRating = try dbQueue.read { db in
            try Rating.fetchOne(db, key: absentRating.id.uuidString)
        }

        XCTAssertNotNil(retrievedRating, "Absent rating should be retrievable")
        XCTAssertNil(retrievedRating?.value, "Absent rating should have nil value")
        XCTAssertTrue(retrievedRating!.isAbsent, "Absent rating should have isAbsent=true")
    }

    func testRatingsByDate() throws {
        // Create a class and a student
        let testClass = Class(
            name: "DateTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Date",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create ratings on different dates
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let rating1 = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: today,
            value: .plus,
            schoolYear: "2024/2025"
        )

        let rating2 = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: yesterday,
            value: .minus,
            schoolYear: "2024/2025"
        )

        let rating3 = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: twoDaysAgo,
            value: .doublePlus,
            schoolYear: "2024/2025"
        )

        // Insert all ratings
        try dbQueue.write { db in
            try rating1.insert(db)
            try rating2.insert(db)
            try rating3.insert(db)
        }

        // Query by date
        let todayRatings = try dbQueue.read { db in
            let startOfToday = calendar.startOfDay(for: today)
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

            return try Rating
                .filter(Column("date") >= startOfToday && Column("date") < endOfToday)
                .fetchAll(db)
        }

        XCTAssertEqual(todayRatings.count, 1, "Should find one rating for today")
        XCTAssertEqual(todayRatings.first?.id, rating1.id, "Should find today's rating")
    }

    func testRatingArchiving() throws {
        // Create a class and a student
        let testClass = Class(
            name: "ArchiveTest",
            row: 1,
            column: 1
        )

        let student = Student(
            firstName: "Archive",
            lastName: "Test",
            classId: testClass.id
        )

        // Insert them
        try dbQueue.write { db in
            try testClass.insert(db)
            try student.insert(db)
        }

        // Create a rating
        let rating = Rating(
            studentId: student.id,
            classId: testClass.id,
            date: Date(),
            value: .plus,
            isArchived: false,
            schoolYear: "2024/2025"
        )

        // Insert the rating
        try dbQueue.write { db in
            try rating.insert(db)
        }

        // Archive the rating
        var archivedRating = rating
        archivedRating.isArchived = true

        try dbQueue.write { db in
            try archivedRating.update(db)
        }

        // Query for active ratings (should not find any)
        let activeRatings = try dbQueue.read { db in
            try Rating
                .filter(Column("studentId") == student.id.uuidString)
                .filter(Column("isArchived") == false)
                .fetchAll(db)
        }

        // Query for archived ratings (should find one)
        let archivedRatings = try dbQueue.read { db in
            try Rating
                .filter(Column("studentId") == student.id.uuidString)
                .filter(Column("isArchived") == true)
                .fetchAll(db)
        }

        XCTAssertEqual(activeRatings.count, 0, "Should find no active ratings")
        XCTAssertEqual(archivedRatings.count, 1, "Should find one archived rating")
    }
}
