import HTTPKit
import XCTest

final class HTTPCookieTests: XCTestCase {
    func testCookieParse() throws {
        /// from https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
        guard let (name, value) = HTTPCookies.Value.parse("id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw CookieError()
        }
        XCTAssertEqual(name, "id")
        XCTAssertEqual(value.string, "a3fWa")
        XCTAssertEqual(value.expires, Date(rfc1123: "Wed, 21 Oct 2015 07:28:00 GMT"))
        XCTAssertEqual(value.isSecure, true)
        XCTAssertEqual(value.isHTTPOnly, true)
        
        guard let cookie: (name: String, value: HTTPCookies.Value) = HTTPCookies.Value.parse("vapor=; Secure; HttpOnly") else {
            throw CookieError()
        }
        XCTAssertEqual(cookie.name, "vapor")
        XCTAssertEqual(cookie.value.string, "")
        XCTAssertEqual(cookie.value.isSecure, true)
        XCTAssertEqual(cookie.value.isHTTPOnly, true)
    }
    
    func testCookieIsSerializedCorrectly() throws {
        var httpReq = HTTPRequest(method: .GET, url: "/")
        
        guard let (name, value) = HTTPCookies.Value.parse("id=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw CookieError()
        }
        
        httpReq.cookies = HTTPCookies(dictionaryLiteral: (name, value))
        
        XCTAssertEqual(httpReq.headers.firstValue(name: .cookie), "id=value")
    }
    
    func testMultipleCookiesAreSerializedCorrectly() throws {
        var httpRes = HTTPResponse()
        httpRes.cookies["a"] = HTTPCookies.Value(string: "1")
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("a=1") }.count, 1)
        httpRes.cookies["b"] = HTTPCookies.Value(string: "2")
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("a=1") }.count, 1)
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("b=2") }.count, 1)
        httpRes.cookies["c"] = HTTPCookies.Value(string: "3")
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("a=1") }.count, 1)
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("b=2") }.count, 1)
        XCTAssertEqual(httpRes.headers[.setCookie].filter { $0.contains("c=3") }.count, 1)
    }
}

struct CookieError: Error { }
