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

            _ = try stream.write("GET /plaintext HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Host: qutheory.io")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()

            let parser = RequestParser(maxSize: 100_000)
            let request = try parser.parse(from: stream)
            request.stream = stream

            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.uri.hostname, "qutheory.io")
            XCTAssertEqual(request.uri.defaultPort, 80)
            XCTAssertEqual(request.uri.path, "/plaintext")
            XCTAssertEqual(request.version.major, 1)
            XCTAssertEqual(request.version.minor, 1)
            XCTAssertEqual(request.peerHostname, "1.2.3.4")
            XCTAssertEqual(request.peerPort, 5678)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseEdgecase() {
        do {
            let stream = TestStream()

            _ = try stream.write("GET http://qutheory.io:1337/p_2?query#fragment HTTP/1.4")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Type: application/")
            _ = try stream.writeLineEnd()
            _ = try stream.write(" json")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()

            let request = try RequestParser(maxSize: 100_000).parse(from: stream)
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
            
            _ = try stream.write("GET /plaintext HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Host: qutheory.io")
            _ = try stream.writeLineEnd()
            _ = try stream.write("X-Forwarded-For: 5.6.7.8")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()

            let parser = RequestParser(maxSize: 100_000)
            let request = try parser.parse(from: stream)
            request.stream = stream

            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerHostname, "5.6.7.8")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testParseForwarded() {
        do {
            let stream = TestStream()
            
            _ = try stream.write("GET /plaintext HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Host: qutheory.io")
            _ = try stream.writeLineEnd()
            _ = try stream.write("X-Forwarded-For: 5.6.7.8")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Forwarded: for=192.0.2.60; proto=http; by=203.0.113.43")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            
            let parser = RequestParser(maxSize: 100_000)
            let request = try parser.parse(from: stream)
            request.stream = stream
            
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerHostname, "192.0.2.60")
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
