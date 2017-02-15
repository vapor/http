import URI
import Foundation
import XCTest

class URIQueryTests: XCTestCase {
    static let allTests = [
        ("testRawQuery", testRawQuery)
    ]

    func testRawQuery() throws {
        let uri = try URI("http://example.com?fizz=bu%3Dzz%2Bzz&aaa=bb%2Bccc%26dd")
        XCTAssertEqual(uri.query, "fizz=bu=zz+zz&aaa=bb+ccc&dd")
        XCTAssertEqual(uri.rawQuery, "fizz=bu%3Dzz%2Bzz&aaa=bb%2Bccc%26dd")
    }
}
