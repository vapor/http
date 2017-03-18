#if os(Linux)

import XCTest
@testable import URITests
@testable import HTTPTests
@testable import WebSocketsTests
@testable import SMTPTests
@testable import CookiesTests

XCTMain([
    // URITests
    testCase(URIModificationTests.allTests),
    testCase(URISerializationTests.allTests),
    testCase(URIQueryTests.allTests),

    // HTTPTests
    testCase(HTTPBodyTests.allTests),
    testCase(HTTPHeadersTests.allTests),
    testCase(HTTPParsingTests.allTests),
    testCase(HTTPRequestTests.allTests),
    testCase(HTTPResponseTests.allTests),
    testCase(HTTPVersionTests.allTests),
    testCase(FoundationConversionTests.allTests),

    // WebSocketsTests
    testCase(WebSocketSerializationTests.allTests),
    testCase(WebSocketKeyTests.allTests),
    testCase(WebSocketConnectTests.allTests),

    // SMTPTests
    testCase(EmailAddressTests.allTests),
    testCase(EmailAttachmentTests.allTests),
    testCase(EmailBodyTests.allTests),
    testCase(SMTPClientErrorTests.allTests),
    testCase(SMTPClientTests.allTests),
    testCase(SMTPCredentialsTests.allTests),
    testCase(SMTPExtensionsTests.allTests),
    testCase(SMTPGreetingTests.allTests),
    testCase(SMTPUUIDTests.allTests),

    // CookiesTests
    testCase(CookiesTests.allTests),
    testCase(CookieTests.allTests),
    testCase(HTTPTests.allTests),
    testCase(ParsingTests.allTests),
    testCase(SerializingTests.allTests)
])

#endif
