import HTTPKit
import XCTest

final class HTTPHeaderTests: XCTestCase {
    func testAcceptHeader() throws {
        let httpReq = HTTPRequest(method: .GET, url: "/", headers: ["Accept": "text/html, application/json, application/xml;q=0.9, */*;q=0.8"])
        XCTAssertTrue(httpReq.accept.mediaTypes.contains(.html))
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .xml), .orderedAscending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .plainText, to: .html), .orderedDescending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .json), .orderedSame)
    }

}
