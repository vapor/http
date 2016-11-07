import XCTest
import URI
@testable import HTTP

class HTTPConversionTests: XCTestCase {
    func testUriToUrlConversion() throws {
        let expectation = "https://google.com:443/search?foo=bar#frag"
        let uri = try URI(expectation)
        let url = try uri.makeFoundationURL()

        XCTAssertEqual(uri.scheme, url.scheme)
        XCTAssertEqual(uri.userInfo?.username, url.user)
        XCTAssertEqual(uri.userInfo?.info, url.password)
        XCTAssertEqual(uri.host, url.host)
        XCTAssertEqual(uri.port, url.port)
        XCTAssertEqual(uri.query, url.query)
        XCTAssertEqual(uri.fragment, url.fragment)

        XCTAssertEqual("\(uri)", expectation)
        XCTAssertEqual(url.absoluteString, expectation)
    }
}
