import Async
import Bits
import Dispatch
import HTTP
import XCTest

class ParserTests : XCTestCase {
    let loop = try! DefaultEventLoop(label: "test")
    
    func testRequest() throws {
        var data = """
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

        let parser = HTTPRequestParser().stream(on: loop)
        var message: HTTPRequest?
        var completed = false
        
        parser.drain { upstream in
            upstream.request()
        }.output { _message in
            message = _message
        }.catch { error in
            XCTFail("\(error)")
        }.finally {
            completed = true
        }
        
        parser.request()
        XCTAssertNil(message)
        data.withByteBuffer(parser.next)
        parser.close()
        
        guard let req = message else {
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
        
        data = try req.body.makeData(max: 100_000).blockingAwait()
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
        XCTAssert(completed)
    }

    func testResponse() throws {
        var data = """
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
        
        let parser = HTTPResponseParser().stream(on: loop)
        var message: HTTPResponse?
        var completed = false
        
        parser.drain { upstream in
            upstream.request()
        }.output { _message in
            message = _message
        }.catch { error in
            XCTFail("\(error)")
        }.finally {
            completed = true
        }
        
        parser.request()
        XCTAssertNil(message)
        data.withByteBuffer(parser.next)
        parser.close()
        
        guard let res = message else {
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
        
        data = try res.body.makeData(max: 100_000).blockingAwait()
        XCTAssertEqual(String(data: data, encoding: .utf8), "<vapor>")
        XCTAssert(completed)
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
        let p = HTTPRequestParser()
        p.maxHeaderSize = data.count - 20 // body
        let parser = p.stream(on: loop)
        
        var completed = false
        
        parser.drain { _ in }.output { _ in
            XCTFail()
        }.catch { _ in
            error = true
        }.finally {
            completed = true
        }
        
        parser.request()
        data.withByteBuffer(parser.next)
        parser.close()
        XCTAssert(error)
        XCTAssert(completed)
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
        let p = HTTPResponseParser()
        p.maxHeaderSize = data.count - 20 // body
        let parser = p.stream(on: loop)
        
        var completed = false
        
        parser.drain { _ in }.output { _ in
            XCTFail()
        }.catch { _ in
            error = true
        }.finally {
            completed = true
        }
        
        parser.request()
        
        data.withByteBuffer(parser.next)
        data.withByteBuffer(parser.next)
        parser.close()
        XCTAssert(error)
        XCTAssert(completed)
    }

    static let allTests = [
        ("testRequest", testRequest),
        ("testResponse", testResponse),
        ("testTooLargeRequest", testTooLargeRequest),
        ("testTooLargeResponse", testTooLargeResponse),
    ]
}


