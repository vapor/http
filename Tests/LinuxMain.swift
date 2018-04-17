#if os(Linux)

import XCTest
@testable import HTTPTests
XCTMain([
    testCase(HTTPTests.allTests),
    testCase(HTTPClientTests.allTests),
])

#endif
