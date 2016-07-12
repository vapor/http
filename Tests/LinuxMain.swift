#if os(Linux)

import XCTest
@testable import BaseTestSuite
@testable import EngineTestSuite
@testable import WebSocketsTestSuite
@testable import SMTPTestSuite

XCTMain([
    // BaseTestSuite
    testCase(PromiseTests.allTests),
    testCase(UtilityTests.allTests),
    testCase(PercentEncodingTests.allTests),
    testCase(UnsignedIntegerChunkingTests.allTests),

    // EngineTestSuite
    testCase(HTTPBodyTests.allTests),
    testCase(HTTPHeadersTests.allTests),
    testCase(HTTPRequestTests.allTests),
    testCase(HTTPStreamTests.allTests),
    testCase(HTTPVersionTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(StreamBufferTests.allTests),
    testCase(URISerializationTests.allTests),

    // WebSocketsTestSuite
    testCase(WebSocketSerializationTests.allTests),
    testCase(WebSocketKeyTests.allTests),

    // SMTPTestSuite
    testCase(EmailAddressTests.allTests),
    testCase(EmailAttachmentTests.allTests),
    testCase(EmailBodyTests.allTests),
    testCase(SMTPClientConvenienceTests.allTests),
    testCase(SMTPClientErrorTests.allTests),
    testCase(SMTPClientTests.allTests),
    testCase(SMTPCredentialsTests.allTests),
    // testCase(SMTPDateTests.allTests),
    testCase(SMTPExtensionsTests.allTests),
    testCase(SMTPGreetingTests.allTests),
    testCase(SMTPUUIDTests.allTests),
])

#endif
