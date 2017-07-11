import XCTest
@testable import HTTP

class HTTPResponseTests: XCTestCase {
    static let allTests = [
       ("testRedirect", testRedirect),
       ("testPermanentRedirect", testPermanentRedirect)
    ]

    func testRedirect() {
        let url = "http://tanner.xyz"

        let redirect = Response(redirect: url)
        XCTAssertEqual(redirect.headers["location"], url, "Location header should be in headers")
        XCTAssertEqual(redirect.status.statusCode, 303, "Temporary redirects should use status '303 See Other'")
    }

    func testPermanentRedirect() {
        let url = "http://tanner.xyz"
        
        let redirect = Response(redirect: url, .permanent)
        XCTAssertEqual(redirect.headers["location"], url, "Location header should be in headers")
        XCTAssertEqual(redirect.status.statusCode, 301, "Permanent redirects should use status '301 Moved Permanently'")
    }
}
