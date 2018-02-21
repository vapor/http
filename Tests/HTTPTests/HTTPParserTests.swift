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

        // creates a protocol tester
        let tester = ProtocolTester(
            data: "GET /hello HTTP/1.1\r\nContent-Type: text/plain\r\nContent-Length:  5\r\n\r\nworld",
            onFail: XCTFail
        ) {
            request = nil
            content = nil
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
            // closed
        }

        try tester.run().blockingAwait()
    }

    func testChunkedResponse() throws {
        let data = """
        HTTP/1.1 200 OK\r
        Content-Type: text/plain\r
        Transfer-Encoding: chunked\r
        \r
        7\r
        Mozilla\r
        9\r
        Developer\r
        7\r
        Network\r
        0\r
        \r

        """

        // captured variables to check
        var response: HTTPResponse?
        var content: String?

        // creates a protocol tester
        let tester = ProtocolTester(
            data: data,
            onFail: XCTFail
        ) {
            response = nil
            content = nil
        }

        tester.assert(before: "chunked\r\n\r\n") {
            guard response == nil else {
                throw "response was not nil"
            }
        }

        tester.assert(after: "chunked\r\n\r\n") {
            guard let res = response else {
                throw "request was nil"
            }

            let contentType = res.headers[.contentType]
            guard contentType == "text/plain" else {
                throw "incorrect content type: \(contentType ?? "nil")"
            }

            guard res.headers[.transferEncoding] == "chunked" else {
                throw "incorrect transfer encoding"
            }
        }

        tester.assert(before: "0\r\n") {
            guard content == nil else {
                throw "content was not nil"
            }
        }

        tester.assert(after: "0\r\n\r\n") {
            guard let string = content else {
                throw "content was nil"
            }

            guard string == "MozillaDeveloperNetwork" else {
                throw "incorrect string: \(string)"
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
    
    func testLargeHeadersRequest() throws {
        // captured variables to check
        var request: HTTPRequest?
        var content: String?
        
        let headers = "Content-Type: text/plain\r\nContent-Length:  5\r\n"
        
        // creates a protocol tester
        let tester = ProtocolTester(
            data: "GET /hello HTTP/1.1\r\n" + headers + "\r\nworld",
            onFail: XCTFail
        ) {
            request = nil
            content = nil
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
        
        var passed = true
        
        let parser = HTTPRequestParser()
        parser.maxStartLineAndHeadersSize = headers.utf8.count &- 10
        let promise = Promise<Void>()
        
        // configure parser stream
        tester.stream(to: parser).drain { message in
            request = message
            message.body.makeData(max: 100).do { data in
                content = String(data: data, encoding: .ascii)
            }.catch { error in
                XCTFail("body error: \(error)")
            }
        }.catch { error in
            passed = false
        }.finally {
            XCTAssertNil(content, "The body should not have been parsed")
            // closed
            promise.complete()
        }
        
        _ = tester.run()
        try promise.future.blockingAwait()
        XCTAssert(!passed, "This message should not be parsing since the headers are too large")
    }
    

    static let allTests = [
        ("testRequest", testRequest),
        ("testChunkedResponse", testChunkedResponse),
        ("testLargeHeadersRequest", testLargeHeadersRequest),
    ]
}
