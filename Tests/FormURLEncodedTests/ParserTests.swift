@testable import FormURLEncoded
import XCTest

class FormURLEncodedParserTests: XCTestCase {
    func testBasic() throws {
        let data = "hello=world&foo=bar".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data: data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar"])
    }

    func testDictionary() throws {
        let data = "greeting[en]=hello&greeting[es]=hola".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data: data)
        XCTAssertEqual(form, ["greeting": ["es": "hola", "en": "hello"]])
    }

    func testArray() throws {
        let data = "greetings[]=hello&greetings[]=hola".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data: data)
        XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }

    func testOptions() throws {
        let data = "hello=&foo".data(using: .utf8)!
        let normal = try! FormURLEncodedParser.default.parse(data: data)
        let noEmpty = try! FormURLEncodedParser.default.parse(data: data, omitEmptyValues: true)
        let noFlags = try! FormURLEncodedParser.default.parse(data: data, omitFlags: true)

        XCTAssertEqual(normal, ["hello": "", "foo": "true"])
        XCTAssertEqual(noEmpty, ["foo": "true"])
        XCTAssertEqual(noFlags, ["hello": ""])
    }

    func testPercentDecoding() throws {
        let data = "aaa%5D=%2Bbbb%20+ccc&d%5B%5D=1&d%5B%5D=2"
        let form = try FormURLEncodedParser.default.parse(percentEncoded: data)
        XCTAssertEqual(form, ["aaa]": "+bbb  ccc", "d": ["1","2"]])
    }

    func testNestedParsing() throws {
        // a[][b]=c&a[][b]=c
        // [a:[[b:c],[b:c]]
        let data = "a[b][c][d][hello]=world".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data: data)
        XCTAssertEqual(form, ["a": ["b": ["c": ["d": ["hello": "world"]]]]])
    }

    static let allTests = [
        ("testBasic", testBasic),
        ("testDictionary", testDictionary),
        ("testArray", testArray),
        ("testOptions", testOptions),
        ("testPercentDecoding", testPercentDecoding),
        ("testNestedParsing", testNestedParsing),
    ]
}

