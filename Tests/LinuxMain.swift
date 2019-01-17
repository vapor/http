import XCTest

@testable import NetKitTests

// MARK: NetKitTests

extension NetKitTests.HTTPClientTests {
	static let __allHTTPClientTestsTests = [
		("testHTTPBin418", testHTTPBin418),
		("testHTTPBinRobots", testHTTPBinRobots),
		("testHTTPBinAnything", testHTTPBinAnything),
		("testGoogleAPIsFCM", testGoogleAPIsFCM),
		("testExampleCom", testExampleCom),
		("testZombo", testZombo),
		("testVaporWithTLS", testVaporWithTLS),
		("testQuery", testQuery),
	]
}

extension NetKitTests.HTTPTests {
	static let __allHTTPTestsTests = [
		("testCookieParse", testCookieParse),
		("testCookieIsSerializedCorrectly", testCookieIsSerializedCorrectly),
		("testAcceptHeader", testAcceptHeader),
		("testRemotePeer", testRemotePeer),
		("testLargeResponseClose", testLargeResponseClose),
	]
}

extension NetKitTests.WebSocketTests {
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

