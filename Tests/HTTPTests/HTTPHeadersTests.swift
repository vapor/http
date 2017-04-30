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
            try stream.write("GET / HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Host: localhost:8080")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let req = try RequestParser<TestStream>(stream: stream).parse()
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
            
            try stream.write("GET /plaintext HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Cookie: 1=1;")
            try stream.writeLineEnd()
            try stream.write(" 2=2;")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let req = try RequestParser<TestStream>(stream: stream).parse()
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

            try stream.write(" ") // this is bad
            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            _ = try RequestParser<TestStream>(stream: stream).parse()
            XCTFail("Headers init should have thrown")
        } catch ParserError.invalidRequest {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testKeyWhitespaceError() {
        do {
            let stream = TestStream()
            try stream.write("GET / HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Accept : */*")
            //                     ^ this is bad
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            _ = try RequestParser<TestStream>(stream: stream).parse()
            XCTFail("Headers init should have thrown")
        } catch ParserError.invalidRequest {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
