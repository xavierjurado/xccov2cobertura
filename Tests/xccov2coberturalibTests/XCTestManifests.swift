import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(xccov2coberturalibTests.allTests),
    ]
}
#endif