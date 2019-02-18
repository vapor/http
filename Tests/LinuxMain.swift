import XCTest

@testable import HTTPKitTests

// MARK: NetKitTests

extension HTTPKitTests.HTTPClientTests {
	static let __allHTTPClientTestsTests = [
		("testHTTPBin418", testHTTPBin418),
		("testHTTPBinRobots", testHTTPBinRobots),
		("testHTTPBinAnything", testHTTPBinAnything),
		("testGoogleAPIsFCM", testGoogleAPIsFCM),
		("testExampleCom", testExampleCom),
		("testZombo", testZombo),
		("testVaporWithTLS", testVaporWithTLS),
        ("testGoogleWithTLS", testGoogleWithTLS),
        ("testSNIWebsite", testSNIWebsite),
		("testQuery", testQuery),
	]
}

extension HTTPKitTests.HTTPTests {
	static let __allHTTPTestsTests = [
		("testCookieParse", testCookieParse),
		("testCookieIsSerializedCorrectly", testCookieIsSerializedCorrectly),
		("testAcceptHeader", testAcceptHeader),
		("testRemotePeer", testRemotePeer),
		("testLargeResponseClose", testLargeResponseClose),
		("testUncleanShutdown", testUncleanShutdown),
		("testClientProxyPlaintext", testClientProxyPlaintext),
		("testClientProxyTLS", testClientProxyTLS),
                ("testRFC1123Flip", testRFC1123Flip),
	]
}

extension HTTPKitTests.WebSocketTests {
	static let __allWebSocketTestsTests = [
		("testClient", testClient),
		("testClientTLS", testClientTLS),
		("testServer", testServer),
		("testServerContinuation", testServerContinuation),
	]
}

// MARK: Test Runner

#if !os(macOS)
public func __buildTestEntries() -> [XCTestCaseEntry] {
	return [
		// NetKitTests
		testCase(HTTPClientTests.__allHTTPClientTestsTests),
		testCase(HTTPTests.__allHTTPTestsTests),
		testCase(WebSocketTests.__allWebSocketTestsTests),
	]
}

let tests = __buildTestEntries()
XCTMain(tests)
#endif

