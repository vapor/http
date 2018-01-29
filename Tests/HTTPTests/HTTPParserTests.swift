import Async
import Bits
import Dispatch
import HTTP
import XCTest

class HTTPParserTests: XCTestCase {
    func testRequest() throws {
        // captured variables to check
        var request: HTTPRequest?
        var content: String?
        var isClosed = false

        // creates a protocol tester
        let tester = ProtocolTester(
            data: "GET /hello HTTP/1.1\r\nContent-Type: text/plain\r\nContent-Length:  5\r\n\r\nworld",
            onFail: XCTFail
        ) {
            request = nil
            content = nil
            isClosed = false
        }

        tester.assert(before: "\r\n\r\n") {
            guard request == nil else {
                throw "request was not nil"
            }
        }

        tester.assert(after: "\r\n\r\n") {
            guard let req = request else {
                throw "request was nil"
            }

            let contentType = req.headers[.contentType]
            guard contentType == "text/plain" else {
                print(req.headers)
                throw "incorrect content type: \(contentType ?? "nil")"
            }

            guard req.headers[.contentLength] == "5" else {
                throw "incorrect content length"
            }
        }

        tester.assert(before: "world") {
            guard content == nil else {
                throw "content was not nil"
            }
        }

        tester.assert(after: "world") {
            guard let string = content else {
                throw "content was nil"
            }

            guard string == "world" else {
                throw "incorrect string"
            }
        }

        // configure parser stream
        tester.stream(to: HTTPRequestParser()).drain { message in
            request = message
            message.body.makeData(max: 100).do { data in
                content = String(data: data, encoding: .ascii)
            }.catch { error in
                XCTFail("body error: \(error)")
            }
        }.catch { error in
            XCTFail("parser error: \(error)")
        }.finally {
            isClosed = true
        }

        try tester.run().blockingAwait()
        XCTAssertTrue(isClosed)
    }

    static let allTests = [
        ("testRequest", testRequest),
    ]
}
