import Foundation
import XCTest
import libc
import Transport

@testable import URI

class URISerializationTests: XCTestCase {
    
    static let allTests = [
        ("testParsing", testParsing),
        ("testPercentEncodedInsideParsing", testPercentEncodedInsideParsing),
        ("testPercentEncodedOutsideParsing", testPercentEncodedOutsideParsing),
        ("testStringInitializer", testStringInitializer),
        //("testBadDecode", testBadDecode),
        ("testInvalidURI", testInvalidURI),
        ("testURIWhitespace", testURIWhitespace),
        // ("testAuthorityNil", testAuthorityNil),
        ("testUserInfo", testUserInfo),
        ("testEmptyScheme", testEmptyScheme)
    ]

    func testParsing() throws {
        /*
         ******** [WARNING] *********

         A lot of these are probably bad URIs, but the test expectations ARE correct.
         Please do not alter tests that look strange without carefully 
         consulting RFC in great detail.
         */
        try makeSure(input: "//google.c@@om:80",
                     equalsScheme: "",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "//google.c@@om:80",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "foo://example.com:8042/over/there?name=ferret#nose",
                     equalsScheme: "foo",
                     host: "example.com",
                     username: "",
                     pass: "",
                     port: 8042,
                     path: "/over/there",
                     query: "name=ferret",
                     fragment: "nose")

        try makeSure(input: "urn:example:animal:ferret:nose",
                     equalsScheme: "urn",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "ftp://ftp.is.co.za/rfc/rfc1808.txt",
                     equalsScheme: "ftp",
                     host: "ftp.is.co.za",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "/rfc/rfc1808.txt",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "http://www.ietf.org/rfc/rfc2396.txt",
                     equalsScheme: "http",
                     host: "www.ietf.org",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "/rfc/rfc2396.txt",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "ldap://[2001:db8::7]/c=GB?objectClass?one",
                     equalsScheme: "ldap",
                     host: "2001:db8::7",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "/c=GB",
                     query: "objectClass?one",
                     fragment: nil)

        try makeSure(input: "mailto:John.Doe@example.com",
                     equalsScheme: "mailto",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "news:comp.infosystems.www.servers.unix",
                     equalsScheme: "news",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "tel:+1-816-555-1212",
                     equalsScheme: "tel",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "telnet://192.0.2.16:80/",
                     equalsScheme: "telnet",
                     host: "192.0.2.16",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "/",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
                     equalsScheme: "urn",
                     host: "",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: nil,
                     fragment: nil)

        try makeSure(input: "foo://info.example.com?fred",
                     equalsScheme: "foo",
                     host: "info.example.com",
                     username: "",
                     pass: "",
                     port: nil,
                     path: "",
                     query: "fred",
                     fragment: nil)

        try makeSure(input: "http://pokeapi.co/api/v2",
                     equalsScheme: "http",
                     host: "pokeapi.co",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "/api/v2",
                     query: nil,
                     fragment: nil)
    }

    func testPercentEncodedInsideParsing() throws {
        // Some percent encoded characters MUST be filtered BEFORE parsing, this test
        // is designed to ensure that's true
        // let period = "%2E"
        // made one lower cuz it should still parse
        try makeSure(input: "http://www.google.com",
                     equalsScheme: "http",
                     host: "www.google.com",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "",
                     query: nil,
                     fragment: nil)
    }

    func testPercentEncodedOutsideParsing() throws {

        // encoded at: http://www.url-encode-decode.com/
        var encoded = ""
        encoded += "jo%3Da9cy%23%24%3B%40%7E-+%2Bd3c%40+%C2%B5%C2%A"
        encoded += "A%E2%88%86%E2%88%82%C2%A2%C2%A7%C2%B6+%C2%AA%E2"
        encoded += "%80%93o+%E2%80%A2%C2%A1de%CB%87%C3%93%C2%B4%E2%"
        encoded += "80%BA%C2%B0%CB%9B%E2%97%8A%C3%85%C3%9A+whoo%21+"
        encoded += "%26%26"

        var decoded = ""
        decoded += "jo=a9cy#$;@~- +d3c@ µª∆∂¢§¶ ª–o •¡deˇÓ´›°˛◊ÅÚ whoo! &&"

        try makeSure(input: "http://www.google.com?\(encoded)",
                     equalsScheme: "http",
                     host: "www.google.com",
                     username: "",
                     pass: "",
                     port: 80,
                     path: "",
                     query: encoded,
                     fragment: nil)
        
        XCTAssertEqual(encoded.percentDecoded, decoded)
    }

    func testStringInitializer() throws {
        let testString = "https://api.spotify.com/v1/search?q=beyonce&type=artist"
        let uri = try URI(testString)
        XCTAssert(uri.scheme == "https")
        XCTAssert(uri.hostname == "api.spotify.com")
        XCTAssert(uri.port == 443)
        XCTAssert(uri.path == "/v1/search")
        XCTAssert(uri.query == "q=beyonce&type=artist")
    }

    func testBadDecode() {
        let invalid = "Hello%2World" // invalid percent incoding
        XCTAssertEqual(invalid.removingPercentEncoding, nil)
    }

    func testInvalidURI() throws {
        let invalid = "http://<google>.com"
        let uri = try URI(invalid)
        XCTAssertEqual(uri.hostname, "")
    }

    func testURIWhitespace() throws {
        let spaces = "http:// g o o g l e . c o m"
        let uri = try URI(spaces)
        XCTAssertEqual(uri.scheme, "http")
        XCTAssertEqual(uri.hostname, "")
    }

    func testUserInfo() throws {
        let parser = URIParser()

        let uri1 = try parser.parse("http://vapor.codes")
        XCTAssertEqual(uri1.userInfo?.username, nil)

        let uri2 = try parser.parse("http://hello:foo@vapor.codes")
        XCTAssertEqual(uri2.userInfo?.username, "hello")

        let uri = try parser.parse("http://hello:world@vapor.codes")
        XCTAssertEqual(uri.userInfo?.username, "hello")
        XCTAssertEqual(uri.userInfo?.info, "world")
    }

    func testEmptyScheme() throws {
        let parser = URIParser()
        let uri = try parser.parse("http")
        XCTAssert(uri.scheme == "http")
    }

    private func makeSure(
        input: String,
        equalsScheme scheme: String,
        host: String,
        username: String,
        pass: String,
        port: Transport.Port?,
        path: String,
        query: String?,
        fragment: String?,
        line: UInt = #line
    ) throws {
        let uri = URIParser.shared.parse(bytes: input.makeBytes())
        XCTAssertEqual(uri.scheme, scheme, "scheme", line: line)
        XCTAssertEqual(uri.hostname, host, "hostname", line: line)
        let testUsername = uri.userInfo?.username ?? ""
        let testPass = uri.userInfo?.info ?? ""
        XCTAssertEqual(testUsername, username, "username", line: line)
        XCTAssertEqual(testPass, pass, "password", line: line)
        XCTAssertEqual(uri.port, port, "port", line: line)
        XCTAssertEqual(uri.path, path, "path", line: line)
        XCTAssertEqual(uri.query, query, "query", line: line)
        XCTAssertEqual(uri.fragment, fragment, "fragment", line: line)
    }
}
