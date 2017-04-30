import XCTest
@testable import HTTP
import URI

class HTTPRequestTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testParseEdgecase", testParseEdgecase),
        ("testParseXForwardedFor", testParseXForwardedFor),
        ("testParseForwarded", testParseForwarded),
        ("testURLEncoding", testURLEncoding)
    ]

    func testParse() {
        do {
            let stream = TestStream()

            try stream.write("GET /plaintext HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Host: qutheory.io")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let parser = RequestParser<TestStream>(stream: stream)
            let request = try parser.parse()
            request.peerAddress = parser.parsePeerAddress(from: stream, with: request.headers)

            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.uri.hostname, "qutheory.io")
            XCTAssertEqual(request.uri.defaultPort, 80)
            XCTAssertEqual(request.uri.path, "/plaintext")
            XCTAssertEqual(request.version.major, 1)
            XCTAssertEqual(request.version.minor, 1)
            XCTAssertEqual(request.peerAddress?.address(), "1.2.3.4:5678")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseEdgecase() {
        do {
            let stream = TestStream()

            try stream.write("GET http://qutheory.io:1337/p_2?query#fragment HTTP/1.4")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/")
            try stream.writeLineEnd()
            try stream.write(" json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let request = try RequestParser<TestStream>(stream: stream).parse()
            XCTAssertEqual(request.method.description, "GET")
            XCTAssertEqual(request.uri.hostname, "qutheory.io")
            XCTAssertEqual(request.uri.port, 1337)
            XCTAssertEqual(request.uri.path, "/p_2")
            XCTAssertEqual(request.uri.fragment, "fragment")
            XCTAssertEqual(request.version.major, 1)
            XCTAssertEqual(request.version.minor, 4)
            XCTAssertEqual(request.headers["accept"], "*/*")
            XCTAssertTrue(request.headers[.contentType]?.contains("application/ json") == true)
        } catch {
            print("ERRRR: \(error)")
            XCTFail("\(error)")
        }
    }
    
    func testParseXForwardedFor() {
        do {
            let stream = TestStream()
            
            try stream.write("GET /plaintext HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Host: qutheory.io")
            try stream.writeLineEnd()
            try stream.write("X-Forwarded-For: 5.6.7.8")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let parser = RequestParser<TestStream>(stream: stream)
            let request = try parser.parse()
            request.peerAddress = parser.parsePeerAddress(from: stream, with: request.headers)

            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerAddress?.address(), "5.6.7.8")
            XCTAssertEqual(request.peerAddress?.xForwardedFor, "5.6.7.8")
            XCTAssertEqual(request.peerAddress?.stream, "1.2.3.4:5678")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testParseForwarded() {
        do {
            let stream = TestStream()
            
            try stream.write("GET /plaintext HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Host: qutheory.io")
            try stream.writeLineEnd()
            try stream.write("X-Forwarded-For: 5.6.7.8")
            try stream.writeLineEnd()
            try stream.write("Forwarded: for=192.0.2.60; proto=http; by=203.0.113.43")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let parser = RequestParser<TestStream>(stream: stream)
            let request = try parser.parse()
            request.peerAddress = parser.parsePeerAddress(from: stream, with: request.headers)
            
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerAddress?.address(), "for=192.0.2.60; proto=http; by=203.0.113.43")
            XCTAssertEqual(request.peerAddress?.forwarded, "for=192.0.2.60; proto=http; by=203.0.113.43")
            XCTAssertEqual(request.peerAddress?.xForwardedFor, "5.6.7.8")
            XCTAssertEqual(request.peerAddress?.stream, "1.2.3.4:5678")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testURLEncoding() throws {
        // TODO: Make this test actually cover all edge cases. Different parts of the URL
        // have different character sets:
        // Refer to:
        // http://stackoverflow.com/a/24552028/1784384
        // https://tools.ietf.org/html/rfc3986#section-2.1
        
        let uri = "https://test.com/?hithere%7Chi"
        _ = Request(method: .get, uri: uri)
        // FIXME
        // XCTAssertEqual(request.startLine, "GET /?hithere%7Chi HTTP/1.1")
    }
}
