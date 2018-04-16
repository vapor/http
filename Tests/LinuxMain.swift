#if os(Linux)

import XCTest
@testable import HTTPTests
XCTMain([
    testCase(HTTPClientTests.allTests),
])

#endif
