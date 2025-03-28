// Place in: hero4Tests/hero4Tests.swift

import TestingFoundation
@testable import hero4
import Testing

// Note: If you're using the new Xcode testing framework, use this structure
// Otherwise, use the traditional XCTest structure below

struct hero4Tests {

    @Test func databaseTests() async throws {
        // Run database tests
        let testDatabase = try TestDatabase()
        let dataStore = testDatabase.dataStore

        // Add a test class
        let testClass = Class(
            name: "IntegrationTest",
            row: 1,
            column: 1
        )

        dataStore.addClass(testClass)

        // Verify it was added
        let retrievedClass = dataStore.getClass(id: testClass.id)
        #expect(retrievedClass != nil)
        #expect(retrievedClass?.name == "IntegrationTest")

        // Clean up
        try testDatabase.reset()
    }
}

// Traditional XCTest approach (use this if you're not using the new Testing framework)
/*
class hero4Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(true)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
*/
