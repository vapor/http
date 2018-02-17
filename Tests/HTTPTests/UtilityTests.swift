@testable import HTTP
import XCTest

class UtilityTests : XCTestCase {
    func testRFC1123() {
        guard let date = RFC1123().formatter.date(from: "Fri, 12 Feb 2010 05:23:03 GMT") else {
            XCTFail()
            return
        }
        
        let string = RFC1123().formatter.string(from: date)
        
        XCTAssertEqual(string, "Fri, 12 Feb 2010 05:23:03 GMT")
    }
    
    func testHTTPURIs() {
        XCTAssertEqual(URI.defaultPorts["ws"], 80)
        XCTAssertEqual(URI.defaultPorts["wss"], 443)
        XCTAssertEqual(URI.defaultPorts["http"], 80)
        XCTAssertEqual(URI.defaultPorts["https"], 443)
    }
    
    func testURIConstruction() throws {
        XCTAssertEqual(URI(scheme: "http", hostname: "localhost", port: 80).rawValue, "http://localhost:80/")
        XCTAssertEqual(URI(scheme: "http://", hostname: "localhost", port: 80).rawValue, "http://localhost:80/")
        XCTAssertEqual(URI(scheme: "http", hostname: "localhost").rawValue, "http://localhost/")
        XCTAssertEqual(URI(scheme: "http://", hostname: "localhost").rawValue, "http://localhost/")
    }
    
    func testURIEmptyPath() throws {
        let emptyPathURI = URI("http://localhost")
        
        XCTAssertEqual(emptyPathURI.path, "/")
    }
    
    func testMethod() {
        XCTAssertEqual(HTTPMethod.get, "GET")
        XCTAssertEqual(HTTPMethod.post, HTTPMethod("post"))
    }
    
    func testCookie() {
        var cookie = Cookie(named: "token", value: "Hello World")
        XCTAssertEqual(cookie.serialized(), "token=Hello World")
        
        cookie = Cookie(from: cookie.serialized())!
        XCTAssertEqual(cookie.name, "token")
        XCTAssertEqual(cookie.value.value, "Hello World")
        
        let date = Date()
        let dateString = RFC1123().formatter.string(from: date)
        
        cookie.value.httpOnly = true
        cookie.value.expires = date
        cookie.value.value = "Test"
        XCTAssertEqual(cookie.serialized(), "token=Test; Expires=\(dateString); HttpOnly")
        
        cookie = Cookie(from: cookie.serialized())!
        XCTAssertEqual(cookie.name, "token")
        XCTAssertEqual(cookie.value.value, "Test")
        XCTAssertEqual(Int(cookie.value.expires?.timeIntervalSince1970 ?? 0), Int(date.timeIntervalSince1970))
        XCTAssertEqual(cookie.value.httpOnly, true)
    }
    
    func testCookieArray() {
        var cookies: Cookies = [
            Cookie(named: "abc", value: "123")
        ]
        
        XCTAssertNil(cookies["ABC"])
        XCTAssertEqual(cookies["abc"]?.value, "123")
    }
    
    func testCookiesDict() {
        var cookies: Cookies = [
            "session": "test",
            "token2": "abc123"
        ]
        
        XCTAssertEqual(cookies["session"]?.value, "test")
        XCTAssertNil(cookies["SessioN"]?.value)
        XCTAssertEqual(cookies["token2"]?.value, "abc123")
        
        cookies["token2"] = "123abc"
        XCTAssertEqual(cookies["token2"]?.value, "123abc")
        
        cookies["test"] = "test"
        
        for cookie in cookies {
            XCTAssert(["session", "token2", "test"].contains(cookie.name))
            XCTAssert(["123abc", "test"].contains(cookie.value.value))
        }
        
        XCTAssertEqual(cookies.cookies.count, 3)
    }
    
    func testCookiesInitializer() {
        var cookies = Cookies()
        
        XCTAssertNil(cookies["hello"])
        
        cookies["hello"] = "world"
        
        XCTAssertEqual(cookies["hello"]?.value, "world")
    }
    
    func testMediaType() throws {
        let req = HTTPRequest(method: .get, uri: "/", headers: [.contentType: "application/json"])
        
        XCTAssertEqual(req.mediaType, .json)
        XCTAssertEqual(req.mediaType?.description, "application/json")
    }
    
    func testBasicMethods() {
        XCTAssertEqual(HTTPMethod.get.string, "GET")
        XCTAssertEqual(HTTPMethod.put.string, "PUT")
        XCTAssertEqual(HTTPMethod.post.string, "POST")
        XCTAssertEqual(HTTPMethod.patch.string, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.string, "DELETE")
    }
    
    func testURISanity() {
        var uri: URI = "https://joannis@github.com:8182/vapor/vapor?hello=world#test"
        
        XCTAssertEqual(uri.scheme, "https")
        XCTAssertEqual(uri.hostname, "github.com")
        XCTAssertEqual(uri.port, 8182)
        XCTAssertEqual(uri.path, "/vapor/vapor")
        XCTAssertEqual(uri.query, "hello=world")
        XCTAssertEqual(uri.fragment, "test")
        
        XCTAssertEqual(uri.description, "https://joannis@github.com:8182/vapor/vapor?hello=world#test")
        
        uri.scheme = "wss"
        uri.hostname = "example.com"
        uri.port = 22
        uri.path = "/fruits/apples"
        uri.query = "olleh=dlrow"
        uri.fragment = "teeest"
        
        XCTAssertEqual(uri.description, "wss://joannis@example.com:22/fruits/apples?olleh=dlrow#teeest")
    }
    
    static let allTests = [
        ("testRFC1123", testRFC1123),
        ("testHTTPURIs", testHTTPURIs),
        ("testURIConstruction", testURIConstruction),
        ("testURIEmptyPath", testURIEmptyPath),
        ("testMethod", testMethod),
        ("testCookie", testCookie),
        ("testCookieArray", testCookieArray),
        ("testCookiesDict", testCookiesDict),
        ("testCookiesInitializer", testCookiesInitializer),
        ("testMediaType", testMediaType),
        ("testBasicMethods", testBasicMethods),
        ("testURISanity", testURISanity),
    ]
}
