import XCTest
@testable import xccov2coberturalib

final class xccov2coberturalibTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(xccov2coberturalib().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
