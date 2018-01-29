import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

class HTTPHeaderTests: XCTestCase {
    func testHeaders() throws {
        var headers = HTTPHeaders()
        XCTAssertEqual(headers.description, "Content-Length: 0\r\n")
        headers[.contentType] = "text/plain"
        XCTAssertEqual(headers.description, "Content-Length: 0\r\nContent-Type: text/plain\r\n")
        headers[.contentType] = "text/plain"
        XCTAssertEqual(headers.description, "Content-Length: 0\r\nContent-Type: text/plain\r\n")
        headers[.contentType] = nil
        XCTAssertEqual(headers.description, "Content-Length: 0\r\n")
        headers[.contentType] = nil
        headers[.contentType] = nil
        headers[.contentType] = nil
        XCTAssertEqual(headers.description, "Content-Length: 0\r\n")
        let hugeString = String(repeating: "hi", count: 25_000)
        headers[HTTPHeaderName("foo")] = hugeString
        XCTAssertEqual(headers.description, "Content-Length: 0\r\nfoo: \(hugeString)\r\n")
        headers[HTTPHeaderName("FOO")] = nil
        XCTAssertEqual(headers.description, "Content-Length: 0\r\n")
    }

    func testHeaderDisplacement() throws {
        var headers = HTTPHeaders()
        XCTAssertEqual(headers.description, "Content-Length: 0\r\n")

        headers[.contentType] = "text/plain"
        XCTAssertEqual(headers.description, "Content-Length: 0\r\nContent-Type: text/plain\r\n")

        headers[.contentLength] = "42"
        XCTAssertEqual(headers.description, "Content-Type: text/plain\r\nContent-Length: 42\r\n")

        XCTAssertEqual(headers[.contentLength], "42")
        XCTAssertEqual(headers[.contentType], "text/plain")
    }


    static let allTests = [
        ("testHeaders", testHeaders),
        ("testHeaderDisplacement", testHeaderDisplacement),
    ]
}
