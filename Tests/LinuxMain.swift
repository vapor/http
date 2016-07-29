#if os(Linux)

import XCTest
@testable import TransportTestSuite
@testable import URITestSuite
@testable import HTTPTestSuite
@testable import WebSocketsTestSuite
@testable import SMTPTestSuite

XCTMain([
    // TransportTestSuite
    testCase(SockStreamTests.allTests),
    testCase(StreamBufferTests.allTests),

    // URITestSuite
    testCase(URISerializationTests.allTests),

    // HTTPTestSuite
    testCase(HTTPBodyTests.allTests),
    testCase(HTTPHeadersTests.allTests),
    testCase(HTTPParsingTests.allTests),
    testCase(HTTPRequestTests.allTests),
    testCase(HTTPResponseTests.allTests),
    testCase(HTTPVersionTests.allTests),

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
    testCase(SMTPExtensionsTests.allTests),
    testCase(SMTPGreetingTests.allTests),
    testCase(SMTPUUIDTests.allTests),
])

#endif
