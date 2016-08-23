import XCTest
@testable import HTTP

class HTTPRequestTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testParseEdgecase", testParseEdgecase),
        ("testParseXForwardedFor", testParseXForwardedFor),
        ("testParseForwarded", testParseForwarded)
    ]

    func testParse() {
        do {
            let stream = TestStream()

            try stream.send("GET /plaintext HTTP/1.1")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Host: qutheory.io")
            try stream.sendLine()
            try stream.sendLine()

            let request = try Parser<Request>(stream: stream).parse()
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.uri.host, "qutheory.io")
            XCTAssertEqual(request.uri.defaultPort, 80)
            XCTAssertEqual(request.uri.path, "/plaintext")
            XCTAssertEqual(request.version.major, 1)
            XCTAssertEqual(request.version.minor, 1)
            XCTAssertEqual(request.peerAddress, "1.2.3.4:5678")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseEdgecase() {
        do {
            let stream = TestStream()

            try stream.send("FOO http://qutheory.io:1337/p_2?query#fragment HTTP/4")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Content-Type: application/")
            try stream.sendLine()
            try stream.send(" json")
            try stream.sendLine()
            try stream.sendLine()

            let request = try Parser<Request>(stream: stream).parse()
            XCTAssertEqual(request.method.description, "FOO")
            XCTAssertEqual(request.uri.host, "qutheory.io")
            XCTAssertEqual(request.uri.port, 1337)
            XCTAssertEqual(request.uri.path, "/p_2")
            XCTAssertEqual(request.uri.fragment, "fragment")
            XCTAssertEqual(request.version.major, 4)
            XCTAssertEqual(request.version.minor, 0)
            XCTAssertEqual(request.headers["accept"], "*/*")
            XCTAssertTrue(request.headers["content-type"]?.contains("application/json") == true)
        } catch {
            print("ERRRR: \(error)")
            XCTFail("\(error)")
        }
    }
    
    func testParseXForwardedFor() {
        do {
            let stream = TestStream()
            
            try stream.send("GET /plaintext HTTP/1.1")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Host: qutheory.io")
            try stream.sendLine()
            try stream.send("X-Forwarded-For: 5.6.7.8")
            try stream.sendLine()
            try stream.sendLine()
            
            let request = try Parser<Request>(stream: stream).parse()
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerAddress, "5.6.7.8")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testParseForwarded() {
        do {
            let stream = TestStream()
            
            try stream.send("GET /plaintext HTTP/1.1")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Host: qutheory.io")
            try stream.sendLine()
            try stream.send("X-Forwarded-For: 5.6.7.8")
            try stream.sendLine()
            try stream.send("Forwarded: for=192.0.2.60; proto=http; by=203.0.113.43")
            try stream.sendLine()
            try stream.sendLine()
            
            let request = try Parser<Request>(stream: stream).parse()
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.peerAddress, "for=192.0.2.60; proto=http; by=203.0.113.43")
        } catch {
            XCTFail("\(error)")
        }
    }
}
