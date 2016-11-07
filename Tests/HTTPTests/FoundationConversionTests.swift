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

        XCTAssertEqual(uri.description, expectation)
        XCTAssertEqual(url.absoluteString, expectation)
    }

    func testUrlToUriConversion() throws {
        let expectation = "https://google.com:443/search?foo=bar#frag"
        let url = URL(string: expectation)!
        let uri = url.makeURI()

        XCTAssertEqual(url.scheme, uri.scheme)
        XCTAssertEqual(url.user, uri.userInfo?.username)
        XCTAssertEqual(url.password, uri.userInfo?.info)
        XCTAssertEqual(url.host, uri.host)
        XCTAssertEqual(url.port, uri.port)
        XCTAssertEqual(url.query, uri.query)
        XCTAssertEqual(url.fragment, uri.fragment)

        XCTAssertEqual(url.absoluteString, expectation)
        XCTAssertEqual(uri.description, expectation)
    }
}
