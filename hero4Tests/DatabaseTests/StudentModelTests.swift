// Place in: hero4Tests/DatabaseTests/StudentModelTests.swift

import Testing
import GRDB
@testable import hero4

class StudentModelTests: XCTestCase {

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

    func testStudentValidation() {
        // Valid student with both names
        let validStudent = Student(
            firstName: "John",
            lastName: "Doe",
            classId: UUID()
        )

        XCTAssertNoThrow(try validStudent.validate(), "Valid student should not throw on validation")

        // Valid student with only first name
        let firstNameOnlyStudent = Student(
            firstName: "John",
            lastName: "",
            classId: UUID()
        )

        XCTAssertNoThrow(try firstNameOnlyStudent.validate(), "Student with only first name should be valid")

        // Valid student with only last name
        let lastNameOnlyStudent = Student(
            firstName: "",
            lastName: "Doe",
            classId: UUID()
        )

        XCTAssertNoThrow(try lastNameOnlyStudent.validate(), "Student with only last name should be valid")

        // Invalid student with no name
        let noNameStudent = Student(
            firstName: "",
            lastName: "",
            classId: UUID()
        )

        XCTAssertThrowsError(try noNameStudent.validate(), "Student with no name should throw validation error")
    }

    func testStudentDatabaseRoundTrip() throws {
        // Create a class for the student
        let testClass = Class(
            name: "Test",
            row: 1,
            column: 1
        )

        // Insert the class
        try dbQueue.write { db in
            try testClass.insert(db)
        }

        // Create a student
        let originalStudent = Student(
            firstName: "John",
            lastName: "Doe",
            classId: testClass.id,
            notes: "Test notes"
        )

        // Insert into database
        try dbQueue.write { db in
            try originalStudent.insert(db)
        }

        // Read back from database
        let retrievedStudent = try dbQueue.read { db in
            try Student.fetchOne(db, key: originalStudent.id.uuidString)
        }

        // Verify all properties are preserved
        XCTAssertNotNil(retrievedStudent, "Student should be retrievable from database")
        XCTAssertEqual(retrievedStudent?.id, originalStudent.id, "ID should be preserved")
        XCTAssertEqual(retrievedStudent?.firstName, originalStudent.firstName, "First name should be preserved")
        XCTAssertEqual(retrievedStudent?.lastName, originalStudent.lastName, "Last name should be preserved")
        XCTAssertEqual(retrievedStudent?.classId, originalStudent.classId, "Class ID should be preserved")
        XCTAssertEqual(retrievedStudent?.notes, originalStudent.notes, "Notes should be preserved")
        XCTAssertEqual(retrievedStudent?.isArchived, originalStudent.isArchived, "Archived status should be preserved")

        // Check date
                let entryDateDifference = abs(retrievedStudent!.entryDate.timeIntervalSince(originalStudent.entryDate))
                XCTAssertLessThan(entryDateDifference, 1.0, "Entry date should be preserved within 1 second")
            }

            func testStudentRelationships() throws {
                // Create a class
                let testClass = Class(
                    name: "StudentTest",
                    row: 1,
                    column: 1
                )

                // Create a student in this class
                let student = Student(
                    firstName: "Relationship",
                    lastName: "Test",
                    classId: testClass.id
                )

                // Create some ratings for this student
                let rating1 = Rating(
                    studentId: student.id,
                    classId: testClass.id,
                    value: .plus,
                    schoolYear: "2024/2025"
                )

                let rating2 = Rating(
                    studentId: student.id,
                    classId: testClass.id,
                    value: .minus,
                    schoolYear: "2024/2025"
                )

                // Insert everything in the database
                try dbQueue.write { db in
                    try testClass.insert(db)
                    try student.insert(db)
                    try rating1.insert(db)
                    try rating2.insert(db)
                }

                // Query ratings for this student
                let ratings = try dbQueue.read { db in
                    try Rating
                        .filter(Column("studentId") == student.id.uuidString)
                        .fetchAll(db)
                }

                XCTAssertEqual(ratings.count, 2, "Student should have 2 ratings")
                XCTAssertTrue(ratings.contains(where: { $0.id == rating1.id }), "Rating 1 should be found")
                XCTAssertTrue(ratings.contains(where: { $0.id == rating2.id }), "Rating 2 should be found")
            }

            func testStudentFullNameComputation() {
                // Test with both names
                let fullNameStudent = Student(
                    firstName: "John",
                    lastName: "Doe",
                    classId: UUID()
                )
                XCTAssertEqual(fullNameStudent.fullName, "John Doe", "Full name should combine first and last names")

                // Test with only first name
                let firstNameStudent = Student(
                    firstName: "John",
                    lastName: "",
                    classId: UUID()
                )
                XCTAssertEqual(firstNameStudent.fullName, "John", "Full name should use first name when last name is empty")

                // Test with only last name
                let lastNameStudent = Student(
                    firstName: "",
                    lastName: "Doe",
                    classId: UUID()
                )
                XCTAssertEqual(lastNameStudent.fullName, "Doe", "Full name should use last name when first name is empty")
            }

            func testStudentSortableName() {
                // Test with both names
                let fullNameStudent = Student(
                    firstName: "John",
                    lastName: "Doe",
                    classId: UUID()
                )
                XCTAssertEqual(fullNameStudent.sortableName, "Doe, John", "Sortable name should be 'lastName, firstName'")

                // Test with only first name
                let firstNameStudent = Student(
                    firstName: "John",
                    lastName: "",
                    classId: UUID()
                )
                XCTAssertEqual(firstNameStudent.sortableName, "John", "Sortable name should be first name when last name is empty")
            }

            func testArchivingStudent() throws {
                // Create a class
                let testClass = Class(
                    name: "ArchiveTest",
                    row: 1,
                    column: 1
                )

                // Create a student
                let student = Student(
                    firstName: "Archive",
                    lastName: "Test",
                    classId: testClass.id,
                    isArchived: false
                )

                // Insert them in the database
                try dbQueue.write { db in
                    try testClass.insert(db)
                    try student.insert(db)
                }

                // Archive the student
                var archivedStudent = student
                archivedStudent.isArchived = true

                try dbQueue.write { db in
                    try archivedStudent.update(db)
                }

                // Verify the student is now archived
                let retrievedStudent = try dbQueue.read { db in
                    try Student.fetchOne(db, key: student.id.uuidString)
                }

                XCTAssertNotNil(retrievedStudent, "Student should still exist after archiving")
                XCTAssertTrue(retrievedStudent!.isArchived, "Student should be marked as archived")
            }
        }
