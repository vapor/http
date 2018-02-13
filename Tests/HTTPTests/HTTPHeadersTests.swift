import XCTest
@testable import HTTP

class HTTPHeadersTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testMultilineValue", testMultilineValue),
        ("testValueTrimming", testValueTrimming),
        ("testLeadingWhitespaceError", testLeadingWhitespaceError),
        ("testKeyWhitespaceError", testKeyWhitespaceError),
    ]

    func testParse() {
        do {
            let stream = TestStream()
            _ = try stream.write("GET / HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Host: localhost:8080")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Type: application/json")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()

            let req = try RequestParser(maxSize: 100_000).parse(from: stream)
            XCTAssertEqual(req.headers["accept"], "*/*")
            XCTAssertEqual(req.headers["host"], "localhost:8080")
            XCTAssertEqual(req.headers["content-type"], "application/json")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testMultilineValue() {
        do {
            let stream = TestStream()
            
            _ = try stream.write("GET /plaintext HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Cookie: 1=1;")
            _ = try stream.writeLineEnd()
            _ = try stream.write(" 2=2;")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Type: application/json")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            
            let req = try RequestParser(maxSize: 100_000).parse(from: stream)
            XCTAssertEqual(req.headers["cookie"], "1=1; 2=2;")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testValueTrimming() {
        let value = " ferret\t".makeBytes().trimmed([.space, .horizontalTab]).makeString()
        XCTAssertEqual(value, "ferret")
    }

    func testLeadingWhitespaceError() {
        do {
            let stream = TestStream()

            _ = try stream.write(" ") // this is bad
            _ = try stream.write("Accept: */*")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Type: application/json")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            
            _ = try RequestParser(maxSize: 100_000).parse(from: stream)
            XCTFail("Headers init should have thrown")
        } catch ParserError.invalidMessage {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testKeyWhitespaceError() {
        do {
            let stream = TestStream()
            _ = try stream.write("GET / HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Accept : */*")
            //                     ^ this is bad
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Type: application/json")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            
            _ = try RequestParser(maxSize: 100_000).parse(from: stream)
            XCTFail("Headers init should have thrown")
        } catch ParserError.invalidMessage {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: Utils

import Transport

extension RequestParser {
    func parse(from stream: ReadableStream) throws -> Request {
        var request: Request?
        while request == nil {
            let bytes = try stream.read(max: 2048)
            request = try self.parse(max: bytes.count, from: bytes)
        }
        return request!
    }
}

