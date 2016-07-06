#if os(Linux)

import XCTest
@testable import BaseTestSuite
@testable import EngineTestSuite
@testable import WebSocketsTestSuite

XCTMain([
    // BaseTestSuite
    testCase(PromiseTests.allTests),
    testCase(UtilityTests.allTests),

    // EngineTestSuite
    testCase(HTTPBodyTests.allTests),
    testCase(HTTPHeadersTests.allTests),
    testCase(HTTPRequestTests.allTests),
    testCase(HTTPStreamTests.allTests),
    testCase(HTTPVersionTests.allTests),
    testCase(PercentEncodingTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(StreamBufferTests.allTests),
    testCase(URISerializationTests.allTests),

    // WebSocketsTestSuite
    testCase(WebSocketSerializationTests.allTests),
    testCase(WebSocketKeyTests.allTests),
    testCase(UnsignedIntegerChunkingTests.allTests),
])

#endif
