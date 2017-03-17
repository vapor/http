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

            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Host: localhost:8080")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let headers = try Parser<Request, TestStream>(stream: stream).parseHeaders()
            XCTAssertEqual(headers["accept"], "*/*")
            XCTAssertEqual(headers["host"], "localhost:8080")
            XCTAssertEqual(headers["content-type"], "application/json")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testMultilineValue() {
        do {
            let stream = TestStream()

            try stream.write("Accept: */*")
            try stream.writeLineEnd()
            try stream.write("Cookie: 1=1;")
            try stream.writeLineEnd()
            try stream.write(" 2=2;")
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            let headers = try Parser<Request, TestStream>(stream: stream).parseHeaders()
            XCTAssertEqual(headers["cookie"], "1=1;2=2;")
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

            _ = try Parser<Request, TestStream>(stream: stream).parseHeaders()
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
            try stream.write("Accept : */*")
            //                     ^ this is bad
            try stream.writeLineEnd()
            try stream.write("Content-Type: application/json")
            try stream.writeLineEnd()
            try stream.writeLineEnd()

            _ = try Parser<Request, TestStream>(stream: stream).parseHeaders()
            XCTFail("Headers init should have thrown")
        } catch ParserError.invalidKeyWhitespace {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
