#if os(Linux)

import XCTest
@testable import HTTPTests
@testable import TCPTests
@testable import WebSocketTests

XCTMain([
	// MARK: HTTP
    testCase(ParserTests.allTests),

    // MARK: TCP
    testCase(SocketsTests.allTests),

    // MARK: WebSocket
    testCase(WebSocketTests.allTests),
])

#endif
