import Async
import Bits
import HTTP
import Foundation
import XCTest

class HTTPSerializerTests: XCTestCase {
    func testResponse() throws {
        // captured variables to check
        var response: HTTPResponse?
        var content: String?

        // creates a protocol tester
        let tester = ProtocolTester(
            data: "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length:  5\r\n\r\nworld",
            onFail: XCTFail
        ) {
            response = nil
            content = nil
        }

        tester.assert(before: "\r\n\r\n") {
            guard response == nil else {
                throw "response was not nil"
            }
        }

        tester.assert(after: "\r\n\r\n") {
            guard let res = response else {
                throw "response was nil"
            }

            guard res.headers[.contentType] == "text/plain" else {
                throw "incorrect content type"
            }

            guard res.headers[.contentLength] == "5" else {
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
        tester.stream(to: HTTPResponseParser()).drain { message in
            response = message
            message.body.makeData(max: 100).do { data in
                content = String(data: data, encoding: .ascii)
            }.catch { error in
                XCTFail("body error: \(error)")
            }
        }.catch { error in
            XCTFail("parser error: \(error)")
        }.finally {
            // closed
        }

        try tester.run().blockingAwait()
    }

    static let allTests = [
        ("testResponse", testResponse),
    ]
}

