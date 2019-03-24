import XCTest

import xccov2coberturaTests

var tests = [XCTestCaseEntry]()
tests += xccov2coberturaTests.allTests()
XCTMain(tests)