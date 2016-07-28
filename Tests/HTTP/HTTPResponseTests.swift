import XCTest
@testable import HTTP

class ResponseTests: XCTestCase {
    static let allTests = [
       ("testRedirect", testRedirect)
    ]

    func testRedirect() {
        let url = "http://tanner.xyz"

        let redirect = Response(redirect: url)
        XCTAssert(redirect.headers["location"] == url, "Location header should be in headers")
    }
}
