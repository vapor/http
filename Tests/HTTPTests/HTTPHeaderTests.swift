import Async
import Bits
@testable import HTTP
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

    func testHeadersGoogle() throws {
        let text = """
        Content-Type: text/html; charset=UTF-8\r
        Referrer-Policy: no-referrer\r
        Content-Length: 1564\r
        Date: Mon, 29 Jan 2018 22:29:53 GMT\r
        Alt-Svc: hq=":443"; ma=2592000; quic=51303431; quic=51303339; quic=51303338; quic=51303337; quic=51303335,quic=":443"; ma=2592000; v="41,39,38,37,35"\r

        """
        let storage = HTTPHeaderStorage(bytes: Bytes(text.utf8), indexes: [
            HTTPHeaderIndex(nameStartIndex: 0, nameEndIndex: 12, valueStartIndex: 14, valueEndIndex: 38),
            HTTPHeaderIndex(nameStartIndex: 40, nameEndIndex: 55, valueStartIndex: 57, valueEndIndex: 68),
            HTTPHeaderIndex(nameStartIndex: 70, nameEndIndex: 84, valueStartIndex: 86, valueEndIndex: 90),
            HTTPHeaderIndex(nameStartIndex: 92, nameEndIndex: 96, valueStartIndex: 98, valueEndIndex: 127),
            HTTPHeaderIndex(nameStartIndex: 129, nameEndIndex: 136, valueStartIndex: 138, valueEndIndex: 278),
        ])
        var headers = HTTPHeaders(storage: storage)
        XCTAssertEqual(headers.description, text)
        XCTAssertEqual(headers[.contentType], "text/html; charset=UTF-8")
        XCTAssertEqual(headers["Referrer-Policy"], "no-referrer")
        XCTAssertEqual(headers[.contentLength], "1564")
        XCTAssertEqual(headers[.date], "Mon, 29 Jan 2018 22:29:53 GMT")
        XCTAssertEqual(headers["Alt-Svc"], """
        hq=":443"; ma=2592000; quic=51303431; quic=51303339; quic=51303338; quic=51303337; quic=51303335,quic=":443"; ma=2592000; v="41,39,38,37,35"
        """)

        headers[.contentLength] = "1564"
        XCTAssertEqual(headers[.contentType], "text/html; charset=UTF-8")
        XCTAssertEqual(headers["Referrer-Policy"], "no-referrer")
        XCTAssertEqual(headers[.contentLength], "1564")
        XCTAssertEqual(headers[.date], "Mon, 29 Jan 2018 22:29:53 GMT")
        XCTAssertEqual(headers["Alt-Svc"], """
        hq=":443"; ma=2592000; quic=51303431; quic=51303339; quic=51303338; quic=51303337; quic=51303335,quic=":443"; ma=2592000; v="41,39,38,37,35"
        """)

    }

    func testHeadersUpdateContentLength() throws {
        let text1 = """
        Content-Type: text/html\r
        Content-Length: 349\r
        Connection: close\r
        Date: Thu, 15 Feb 2018 01:27:36 GMT\r
        Server: ECSF (lga/1372)\r

        """
        var headers = HTTPHeaders()
        headers[.contentType] = "text/html"
        headers[.contentLength] = 349.description
        headers[.connection] = "close"
        headers[.date] = "Thu, 15 Feb 2018 01:27:36 GMT"
        headers[.server] = "ECSF (lga/1372)"

        XCTAssertEqual(headers.debugDescription, text1)

        let text2 = """
        Content-Type: text/html\r
        Connection: close\r
        Date: Thu, 15 Feb 2018 01:27:36 GMT\r
        Server: ECSF (lga/1372)\r
        Content-Length: 349\r

        """
        headers[.contentLength] = 349.description
        XCTAssertEqual(headers.debugDescription, text2)
    }

    static let allTests = [
        ("testHeaders", testHeaders),
        ("testHeaderDisplacement", testHeaderDisplacement),
        ("testHeadersGoogle", testHeadersGoogle),
    ]
}
