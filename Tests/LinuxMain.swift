#if os(Linux)

import XCTest
@testable import HTTPTests
@testable import MultipartTests
@testable import FormURLEncodedTests
XCTMain([
    testCase(HTTPClientTests.allTests),

    testCase(FormURLEncodedCodableTests.allTests),
    testCase(FormURLEncodedParserTests.allTests),
    testCase(FormURLEncodedSerializerTests.allTests),

    testCase(MultipartTests.allTests),
])

#endif
