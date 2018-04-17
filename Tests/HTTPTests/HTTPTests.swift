import HTTP
import XCTest

class HTTPTests: XCTestCase {
    func testCookieParse() throws {
        /// from https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
        guard let cookie = HTTPCookie.parse("id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
        }

        XCTAssertEqual(cookie.name, "id")
        XCTAssertEqual(cookie.expires, Date(rfc1123: "Wed, 21 Oct 2015 07:28:00 GMT"))
        XCTAssertEqual(cookie.isSecure, true)
        XCTAssertEqual(cookie.isHTTPOnly, true)
    }

    static let allTests = [
        ("testCookieParse", testCookieParse),
    ]
}
