#if os(Linux)

import XCTest
@testable import HTTPTests
@testable import MultipartTests
@testable import FormURLEncodedTests
XCTMain([
	// MARK: HTTP
    testCase(HTTPClientTests.allTests),
    testCase(HTTPServerTests.allTests),
    testCase(HTTPParserTests.allTests),
    testCase(HTTPSerializerTests.allTests),
    testCase(UtilityTests.allTests),

    testCase(FormURLEncodedCodableTests.allTests),
    testCase(FormURLEncodedParserTests.allTests),
    testCase(FormURLEncodedSerializerTests.allTests),

    // MARK: TCP
    testCase(MultipartTests.allTests),
    testCase(SubProtocolMatcherTests.allTests),
])

#endif
