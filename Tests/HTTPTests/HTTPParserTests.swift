import Async
import Bits
import Dispatch
import HTTP
import XCTest

class HTTPParserTests: XCTestCase {
    func testParserEdgeCasesOld() throws {
        let firstChunk = "GET /hello HTTP/1.1\r\nContent-Type: ".data(using: .utf8)!
        let secondChunk = "text/plain\r\nContent-Length: 5\r\n\r\nwo".data(using: .utf8)!
        let thirdChunk = "rl".data(using: .utf8)!
        let fourthChunk = "d".data(using: .utf8)!

        let parser = HTTPRequestParser()

        let socket = PushStream(ByteBuffer.self)
        socket.stream(to: parser).drain { message in
            print("parser.drain { ... }")
            print(message)
            print("message.body.makeData")
            message.body.makeData(max: 100).do { data in
                print(data)
            }.catch { error in
                print("body error: \(error)")
            }
        }.catch { error in
            print("parser.catch { \(error) }")
        }.finally {
            print("parser.close { }")
        }


        print("(1) FIRST ---")
        firstChunk.withByteBuffer(socket.push)
        print("(2) SECOND ---")
        secondChunk.withByteBuffer(socket.push)
        print("(3) THIRD ---")
        thirdChunk.withByteBuffer(socket.push)
        print("(4) FOURTH ---")
        fourthChunk.withByteBuffer(socket.push)

        print("(1) FIRST ---")
        firstChunk.withByteBuffer(socket.push)
        print("(2) SECOND ---")
        secondChunk.withByteBuffer(socket.push)
        print("(3) THIRD ---")
        thirdChunk.withByteBuffer(socket.push)
        print("(4) FOURTH ---")
        fourthChunk.withByteBuffer(socket.push)
        
        print("(c) CLOSE ---")
        socket.close()
    }

    func testParserEdgeCases() throws {
        // captured variables to check
        var request: HTTPRequest?
        var content: String?
        var isClosed = false

        // creates a protocol tester
        let tester = ProtocolTester(
            data: "GET /hello HTTP/1.1\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nworld",
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

            guard req.headers[.contentType] == "text/plain" else {
                throw "incorrect content type"
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


//
//    func testRequest() throws {
//        var data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//
//        let parser = HTTPRequestParser()
//        var message: HTTPRequest?
//        var completed = false
//
//        parser.drain { _message in
//            message = _message
//        }.catch { error in
//            XCTFail("\(error)")
//        }.finally {
//            completed = true
//        }
//
//        XCTAssertNil(message)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//
//        guard let req = message else {
//            XCTFail("No request parsed")
//            return
//        }
//
//        XCTAssertEqual(req.method, .post)
//        XCTAssertEqual(req.headers[.userAgent], "Mozilla/4.0 (compatible; MSIE5.01; Windows NT)")
//        XCTAssertEqual(req.headers[.host], "www.tutorialspoint.com")
//        XCTAssertEqual(req.headers[.contentType], "text/plain")
//        XCTAssertEqual(req.mediaType, .plainText)
//        XCTAssertEqual(req.headers[.contentLength], "5")
//        XCTAssertEqual(req.headers[.acceptLanguage], "en-us")
//        XCTAssertEqual(req.headers[.acceptEncoding], "gzip, deflate")
//        XCTAssertEqual(req.headers[.connection], "Keep-Alive")
//
//        data = try req.body.makeData(max: 100_000).await(on: loop)
//        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
//        XCTAssert(completed)
//    }
//
//    func testResponse() throws {
//        var data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//
//        let parser = HTTPResponseParser()
//        var message: HTTPResponse?
//        var completed = false
//
//        parser.drain { _message in
//            message = _message
//        }.catch { error in
//            XCTFail("\(error)")
//        }.finally {
//            completed = true
//        }
//
//        XCTAssertNil(message)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//
//        guard let res = message else {
//            XCTFail("No request parsed")
//            return
//        }
//
//        XCTAssertEqual(res.status, .ok)
//        XCTAssertEqual(res.headers[.date], "Mon, 27 Jul 2009 12:28:53 GMT")
//        XCTAssertEqual(res.headers[.server], "Apache/2.2.14 (Win32)")
//        XCTAssertEqual(res.headers[.lastModified], "Wed, 22 Jul 2009 19:15:56 GMT")
//        XCTAssertEqual(res.headers[.contentLength], "7")
//        XCTAssertEqual(res.headers[.contentType], "text/html")
//        XCTAssertEqual(res.mediaType, .html)
//        XCTAssertEqual(res.headers[.connection], "Closed")
//
//        data = try res.body.makeData(max: 100_000).blockingAwait()
//        XCTAssertEqual(String(data: data, encoding: .utf8), "<vapor>")
//        XCTAssert(completed)
//    }
//
//    func testTooLargeRequest() throws {
//        let data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//
//        var error = false
//        let p = HTTPRequestParser()
//        p.maxHeaderSize = data.count - 20 // body
//        let parser = p
//
//        var completed = false
//
//        _ = parser.drain { _ in
//            XCTFail()
//        }.catch { _ in
//            error = true
//        }.finally {
//            completed = true
//        }
//
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//        XCTAssert(error)
//        XCTAssert(completed)
//    }

//    func testTooLargeResponse() throws {
//        let data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//
//        var error = false
//        let p = HTTPResponseParser()
//        p.maxHeaderSize = data.count - 20 // body
//        let parser = p.stream(on: loop)
//
//        var completed = false
//
//        _ = parser.drain { _ in
//            XCTFail()
//        }.catch { _ in
//            error = true
//        }.finally {
//            completed = true
//        }
//
//
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//        XCTAssert(error)
//        XCTAssert(completed)
//    }

//    static let allTests = [
//        ("testRequest", testRequest),
//        ("testResponse", testResponse),
//        ("testTooLargeRequest", testTooLargeRequest),
//        ("testTooLargeResponse", testTooLargeResponse),
//    ]
}


