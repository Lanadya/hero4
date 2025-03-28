// Place in: hero4Tests/DatabaseTests/DataStoreTests.swift

import Testing
import GRDB
@testable import hero4

class DataStoreTests: XCTestCase {

    var testDatabase: TestDatabase!
    var dataStore: DataStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDatabase = try TestDatabase()
        dataStore = testDatabase.dataStore
    }

    override func tearDownWithError() throws {
        try testDatabase.reset()
        testDatabase = nil
        dataStore = nil
        try super.tearDownWithError()
    }

    // MARK: - Class Tests

    func testAddClass() throws {
        // Arrange
        let testClass = Class(
            name: "Math101",
            note: "Advanced",
            row: 2,
            column: 3
        )

        // Act
        dataStore.addClass(testClass)

        // Assert
        let retrievedClass = dataStore.getClass(id: testClass.id)
        XCTAssertNotNil(retrievedClass, "Class should be retrievable after adding")
        XCTAssertEqual(retrievedClass?.name, "Math101", "Retrieved class should match added class")
        XCTAssertEqual(retrievedClass?.note, "Advanced", "Note should be preserved")
        XCTAssertEqual(retrievedClass?.row, 2, "Row should be preserved")
        XCTAssertEqual(retrievedClass?.column, 3, "Column should be preserved")
    }

    func testUpdateClass() throws {
        // Arrange
        let testClass = Class(
            name: "Original",
            row: 1,
            column: 1
        )
        dataStore.addClass(testClass)

        // Act
        var updatedClass = testClass
        updatedClass.name = "Updated"
        updatedClass.note = "New Note"
        dataStore.updateClass(updatedClass)

        // Assert
        let retrievedClass = dataStore.getClass(id: testClass.id)
        XCTAssertEqual(retrievedClass?.name, "Updated", "Class name should be updated")
        XCTAssertEqual(retrievedClass?.note, "New Note", "Class note should be updated")
    }

    func testDeleteClass() throws {
        // Arrange
        let testClass = Class(
            name: "ToDelete",
            row: 1,
            column: 1
        )
        dataStore.addClass(testClass)

        // Verify it was added
        XCTAssertNotNil(dataStore.getClass(id: testClass.id), "Class should exist before deletion")

        // Act
        dataStore.deleteClass(id: testClass.id)

        // Assert
        XCTAssertNil(dataStore.getClass(id: testClass.id), "Class should be nil after deletion")
    }

    // MARK: - Student Tests

    func testAddStudent() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(
            firstName: "John",
            lastName: "Doe",
            classId: testClass.id
        )

        // Act
        dataStore.addStudent(student)

        // Assert
        let retrievedStudent = dataStore.getStudent(id: student.id)
        XCTAssertNotNil(retrievedStudent, "Student should be retrievable after adding")
        XCTAssertEqual(retrievedStudent?.firstName, "John", "First name should match")
        XCTAssertEqual(retrievedStudent?.lastName, "Doe", "Last name should match")
        XCTAssertEqual(retrievedStudent?.classId, testClass.id, "Class ID should match")
    }

    func testUpdateStudent() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(
            firstName: "Original",
            lastName: "Student",
            classId: testClass.id
        )
        dataStore.addStudent(student)

        // Act
        var updatedStudent = student
        updatedStudent.firstName = "Updated"
        updatedStudent.lastName = "Name"
        updatedStudent.notes = "New notes"
        dataStore.updateStudent(updatedStudent)

        // Assert
        let retrievedStudent = dataStore.getStudent(id: student.id)
        XCTAssertEqual(retrievedStudent?.firstName, "Updated", "First name should be updated")
        XCTAssertEqual(retrievedStudent?.lastName, "Name", "Last name should be updated")
        XCTAssertEqual(retrievedStudent?.notes, "New notes", "Notes should be updated")
    }

    func testDeleteStudent() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(
            firstName: "Delete",
            lastName: "Me",
            classId: testClass.id
        )
        dataStore.addStudent(student)

        // Verify it was added
        XCTAssertNotNil(dataStore.getStudent(id: student.id), "Student should exist before deletion")

        // Act
        dataStore.deleteStudent(id: student.id)

        // Assert
        XCTAssertNil(dataStore.getStudent(id: student.id), "Student should be nil after deletion")
    }

    func testGetStudentsForClass() throws {
        // Arrange
        let class1 = Class(name: "Class1", row: 1, column: 1)
        let class2 = Class(name: "Class2", row: 2, column: 2)
        dataStore.addClass(class1)
        dataStore.addClass(class2)

        let student1 = Student(firstName: "Student", lastName: "One", classId: class1.id)
        let student2 = Student(firstName: "Student", lastName: "Two", classId: class1.id)
        let student3 = Student(firstName: "Student", lastName: "Three", classId: class2.id)

        dataStore.addStudent(student1)
        dataStore.addStudent(student2)
        dataStore.addStudent(student3)

        // Act
        let class1Students = dataStore.getStudentsForClass(classId: class1.id)
        let class2Students = dataStore.getStudentsForClass(classId: class2.id)

        // Assert
        XCTAssertEqual(class1Students.count, 2, "Class1 should have 2 students")
        XCTAssertEqual(class2Students.count, 1, "Class2 should have 1 student")
        XCTAssertTrue(class1Students.contains { $0.id == student1.id }, "Class1 should contain student1")
        XCTAssertTrue(class1Students.contains { $0.id == student2.id }, "Class1 should contain student2")
        XCTAssertTrue(class2Students.contains { $0.id == student3.id }, "Class2 should contain student3")
    }

    // MARK: - Rating Tests

    func testAddRating() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(firstName: "Rating", lastName: "Test", classId: testClass.id)
        dataStore.addStudent(student)

        let rating = Rating(
            studentId: student.id,
            classId: testClass.id,
            value: .plus,
            schoolYear: "2024/2025"
        )

        // Act
        dataStore.addRating(rating)

        // Assert
        let retrievedRating = dataStore.getRating(id: rating.id)
        XCTAssertNotNil(retrievedRating, "Rating should be retrievable after adding")
        XCTAssertEqual(retrievedRating?.value, .plus, "Rating value should match")
        XCTAssertEqual(retrievedRating?.studentId, student.id, "Student ID should match")
        XCTAssertEqual(retrievedRating?.classId, testClass.id, "Class ID should match")
    }

    func testUpdateRating() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(firstName: "Student", lastName: "Test", classId: testClass.id)
        dataStore.addStudent(student)

        let rating = Rating(
            studentId: student.id,
            classId: testClass.id,
            value: .plus,
            schoolYear: "2024/2025"
        )
        dataStore.addRating(rating)

        // Act
        var updatedRating = rating
        updatedRating.value = .doublePlus
        updatedRating.isAbsent = true
        dataStore.updateRating(updatedRating)

        // Assert
        let retrievedRating = dataStore.getRating(id: rating.id)
        XCTAssertEqual(retrievedRating?.value, .doublePlus, "Rating value should be updated")
        XCTAssertTrue(retrievedRating?.isAbsent ?? false, "Absence status should be updated")
    }

    func testDeleteRating() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(firstName: "Student", lastName: "Test", classId: testClass.id)
        dataStore.addStudent(student)

        let rating = Rating(
            studentId: student.id,
            classId: testClass.id,
            value: .plus,
            schoolYear: "2024/2025"
        )
        dataStore.addRating(rating)

        // Verify it was added
        XCTAssertNotNil(dataStore.getRating(id: rating.id), "Rating should exist before deletion")

        // Act
        dataStore.deleteRating(id: rating.id)

        // Assert
        XCTAssertNil(dataStore.getRating(id: rating.id), "Rating should be nil after deletion")
    }

    // MARK: - Seating Position Tests

    func testSeatingPositions() throws {
        // Arrange
        let testClass = Class(name: "Class", row: 1, column: 1)
        dataStore.addClass(testClass)

        let student = Student(firstName: "Student", lastName: "Test", classId: testClass.id)
        dataStore.addStudent(student)

        let position = SeatingPosition(
            studentId: student.id,
            classId: testClass.id,
            xPos: 3,
            yPos: 4
        )

        // Act - Add position
        dataStore.seatingPositions.append(position)

        // Assert position was added
        let positions = dataStore.seatingPositions.filter {
            $0.studentId == student.id && $0.classId == testClass.id
        }
        XCTAssertEqual(positions.count, 1, "Position should be added")
        XCTAssertEqual(positions.first?.xPos, 3, "X position should match")
        XCTAssertEqual(positions.first?.yPos, 4, "Y position should match")

        // Act - Update position
        var updatedPosition = position
        updatedPosition.xPos = 5
        updatedPosition.yPos = 6

        // Update in array
        if let index = dataStore.seatingPositions.firstIndex(where: { $0.id == position.id }) {
            dataStore.seatingPositions[index] = updatedPosition
        }

        // Assert update worked
        let updatedPositions = dataStore.seatingPositions.filter {
            $0.id == position.id
        }
        XCTAssertEqual(updatedPositions.first?.xPos, 5, "X position should be updated")
        XCTAssertEqual(updatedPositions.first?.yPos, 6, "Y position should be updated")

        // Act - Remove position
        dataStore.seatingPositions.removeAll { $0.id == position.id }

        // Assert removal worked
        let remainingPositions = dataStore.seatingPositions.filter {
            $0.id == position.id
        }
        XCTAssertEqual(remainingPositions.count, 0, "Position should be removed")
    }

    // MARK: - Data Persistence Tests

    func testDataPersistence() throws {
        // This test requires a real file-based database instead of in-memory
        // Create a temporary database file
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test_persistence.sqlite")

        // Remove any existing file
        if fileManager.fileExists(atPath: dbURL.path) {
            try fileManager.removeItem(at: dbURL)
        }

        // Create a database pool
        let dbPool = try DatabasePool(path: dbURL.path)
        try AppDatabase.migrator.migrate(dbPool)

        // Add a class using a temporary DataStore
        do {
            // This would need to be modified based on your actual DataStore implementation
            // For testing, you might need to add a constructor that accepts a DatabasePool
            let tempDataStore = DataStore.shared
            // tempDataStore.setDatabaseForTesting(dbPool: dbPool)

            let testClass = Class(
                name: "PersistenceTest",
                note: "Testing",
                row: 7,
                column: 7
            )

            tempDataStore.addClass(testClass)

            // Store the ID for later verification
            UserDefaults.standard.set(testClass.id.uuidString, forKey: "testPersistenceClassId")
        }

        // Create a new DataStore instance to simulate app restart
        do {
            let newDataStore = DataStore.shared
            // newDataStore.setDatabaseForTesting(dbPool: dbPool)
            newDataStore.loadClasses()

            // Retrieve the stored class ID
            let classIdString = UserDefaults.standard.string(forKey: "testPersistenceClassId")!
            let classId = UUID(uuidString: classIdString)!

            // Verify the class was persisted
            let retrievedClass = newDataStore.getClass(id: classId)
            XCTAssertNotNil(retrievedClass, "Class should be retrieved after simulated app restart")
            XCTAssertEqual(retrievedClass?.name, "PersistenceTest", "Class name should persist")
            XCTAssertEqual(retrievedClass?.note, "Testing", "Class note should persist")
            XCTAssertEqual(retrievedClass?.row, 7, "Class row should persist")
            XCTAssertEqual(retrievedClass?.column, 7, "Class column should persist")
        }

        // Clean up
        try fileManager.removeItem(at: dbURL)
        UserDefaults.standard.removeObject(forKey: "testPersistenceClassId")
    }
}
