import Async
import Bits
import Dispatch
import HTTP
import XCTest

class ParserTests : XCTestCase {
    func testRequest() throws {
        let data = """
        POST /cgi-bin/process.cgi HTTP/1.1\r
        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
        Host: www.tutorialspoint.com\r
        Content-Type: text/plain\r
        Content-Length: 5\r
        Accept-Language: en-us\r
        Accept-Encoding: gzip, deflate\r
        Connection: Keep-Alive\r
        \r
        hello
        """.data(using: .utf8) ?? Data()

        let parser = HTTPRequestParser()
        parser.request()
        XCTAssertNil(parser.message)
        data.withByteBuffer(parser.next)
        
        guard let req = parser.message else {
            XCTFail("No request parsed")
            return
        }

        XCTAssertEqual(req.method, .post)
        XCTAssertEqual(req.headers[.userAgent], "Mozilla/4.0 (compatible; MSIE5.01; Windows NT)")
        XCTAssertEqual(req.headers[.host], "www.tutorialspoint.com")
        XCTAssertEqual(req.headers[.contentType], "text/plain")
        XCTAssertEqual(req.mediaType, .plainText)
        XCTAssertEqual(req.headers[.contentLength], "5")
        XCTAssertEqual(req.headers[.acceptLanguage], "en-us")
        XCTAssertEqual(req.headers[.acceptEncoding], "gzip, deflate")
        XCTAssertEqual(req.headers[.connection], "Keep-Alive")
        
        try req.body.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: req.body.count)
            XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
        }
    }

    func testResponse() throws {
        let data = """
        HTTP/1.1 200 OK\r
        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
        Server: Apache/2.2.14 (Win32)\r
        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
        Content-Length: 7\r
        Content-Type: text/html\r
        Connection: Closed\r
        \r
        <vapor>
        """.data(using: .utf8) ?? Data()
        
        let parser = HTTPResponseParser()
        parser.request()
        XCTAssertNil(parser.message)
        data.withByteBuffer(parser.next)
        
        guard let res = parser.message else {
            XCTFail("No request parsed")
            return
        }

        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.headers[.date], "Mon, 27 Jul 2009 12:28:53 GMT")
        XCTAssertEqual(res.headers[.server], "Apache/2.2.14 (Win32)")
        XCTAssertEqual(res.headers[.lastModified], "Wed, 22 Jul 2009 19:15:56 GMT")
        XCTAssertEqual(res.headers[.contentLength], "7")
        XCTAssertEqual(res.headers[.contentType], "text/html")
        XCTAssertEqual(res.mediaType, .html)
        XCTAssertEqual(res.headers[.connection], "Closed")
        
        try res.body.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: res.body.count)
            XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "<vapor>")
        }
    }
    
    func testTooLargeRequest() throws {
        let data = """
        POST /cgi-bin/process.cgi HTTP/1.1\r
        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
        Host: www.tutorialspoint.com\r
        Content-Type: text/plain\r
        Content-Length: 5\r
        Accept-Language: en-us\r
        Accept-Encoding: gzip, deflate\r
        Connection: Keep-Alive\r
        \r
        hello
        """.data(using: .utf8) ?? Data()
        
        var error = false
        let parser = HTTPRequestParser()
        parser.maxMessageSize = data.count - 2
        
        XCTAssertNil(parser.message)
        parser.drain { upstream in
            upstream.request()
        }.output { _ in
            XCTFail()
        }.catch { _ in
            error = true
        }.finally {}
        
        data.withByteBuffer(parser.next)
        XCTAssert(error)
    }
    
    func testTooLargeResponse() throws {
        let data = """
        HTTP/1.1 200 OK\r
        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
        Server: Apache/2.2.14 (Win32)\r
        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
        Content-Length: 7\r
        Content-Type: text/html\r
        Connection: Closed\r
        \r
        <vapor>
        """.data(using: .utf8) ?? Data()
        
        var error = false
        let parser = HTTPResponseParser()
        parser.maxMessageSize = data.count - 2
        XCTAssertNil(parser.message)
        parser.drain { upstream in
            upstream.request()
        }.output { _ in
            XCTFail()
        }.catch { _ in
            error = true
        }.finally {}
        
        data.withByteBuffer(parser.next)
        XCTAssert(error)
    }

    static let allTests = [
        ("testRequest", testRequest),
        ("testResponse", testResponse),
        ("testTooLargeRequest", testTooLargeRequest),
        ("testTooLargeResponse", testTooLargeResponse),
    ]
}


