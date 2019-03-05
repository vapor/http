import HTTPKit
import XCTest

class HTTPTests: HTTPKitTestCase {
    func testCookieParse() throws {
        /// from https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
        guard let (name, value) = HTTPCookieValue.parse("id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw CookieError()
        }
        XCTAssertEqual(name, "id")
        XCTAssertEqual(value.string, "a3fWa")
        XCTAssertEqual(value.expires, Date(rfc1123: "Wed, 21 Oct 2015 07:28:00 GMT"))
        XCTAssertEqual(value.isSecure, true)
        XCTAssertEqual(value.isHTTPOnly, true)
        
        guard let cookie: (name: String, value: HTTPCookieValue) = HTTPCookieValue.parse("vapor=; Secure; HttpOnly") else {
            throw CookieError()
        }
        XCTAssertEqual(cookie.name, "vapor")
        XCTAssertEqual(cookie.value.string, "")
        XCTAssertEqual(cookie.value.isSecure, true)
        XCTAssertEqual(cookie.value.isHTTPOnly, true)
    }
    
    func testCookieIsSerializedCorrectly() throws {
        var httpReq = HTTPRequest(method: .GET, url: "/")

        guard let (name, value) = HTTPCookieValue.parse("id=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw CookieError()
        }
        
        httpReq.cookies = HTTPCookies(dictionaryLiteral: (name, value))
        
        XCTAssertEqual(httpReq.headers.firstValue(name: .cookie), "id=value")
    }

    func testAcceptHeader() throws {
        let httpReq = HTTPRequest(method: .GET, url: "/", headers: ["Accept": "text/html, application/json, application/xml;q=0.9, */*;q=0.8"])
        XCTAssertTrue(httpReq.accept.mediaTypes.contains(.html))
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .xml), .orderedAscending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .plainText, to: .html), .orderedDescending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .json), .orderedSame)
    }

    func testRemotePeer() throws {
        let client = HTTPClient(on: self.eventLoopGroup)
        let httpReq = HTTPRequest(method: .GET, url: "http://vapor.codes/")
        let httpRes = try client.send(httpReq).wait()
        // TODO: how to get access to channel?
        // XCTAssertEqual(httpRes.remotePeer(on: client.channel).port, 80)
    }
    
    func testLargeResponseClose() throws {
        struct LargeResponder: HTTPServerDelegate {
            func respond(to request: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
                let res = HTTPResponse(
                    status: .ok,
                    body: String(repeating: "0", count: 2_000_000)
                )
                return channel.eventLoop.makeSucceededFuture(res)
            }
        }
        let server = HTTPServer(
            config: .init(
                hostname: "localhost",
                port: 8080,
                supportVersions: [.one],
                errorHandler: { error in
                    XCTFail("\(error)")
                }
            ),
            on: self.eventLoopGroup
        )
        try server.start(delegate: LargeResponder()).wait()
    
        var req = HTTPRequest(method: .GET, url: "http://localhost:8080/")
        req.headers.replaceOrAdd(name: .connection, value: "close")
        let res = try HTTPClient(on: self.eventLoopGroup)
            .send(req).wait()
        XCTAssertEqual(res.body.count, 2_000_000)
        try server.shutdown().wait()
        try server.onClose.wait()
    }
    
    func testUncleanShutdown() throws {
        let res = try HTTPClient(
            config: .init(
                tlsConfig: .forClient(certificateVerification: .none)
            ),
            on: self.eventLoopGroup
        ).get("https://www.google.com/search?q=vapor").wait()
        XCTAssertEqual(res.status, .ok)
    }
    
    func testClientProxyPlaintext() throws {
        let res = try HTTPClient(
            config: .init(
                proxy: .server(hostname: proxyHostname, port: 8888)
            ),
            on: self.eventLoopGroup
        ).get("http://httpbin.org/anything").wait()
        XCTAssertEqual(res.status, .ok)
    }
    
    func testClientProxyTLS() throws {
        let res = try HTTPClient(
            config: .init(
                tlsConfig: .forClient(certificateVerification: .none),
                proxy: .server(hostname: proxyHostname, port: 8888)
            ),
            on: self.eventLoopGroup
        ).get("https://vapor.codes/").wait()
        XCTAssertEqual(res.status, .ok)
    }

    func testRFC1123Flip() throws {
        var now: Date?
        var boundary = 0.0
        while boundary <= 0.01 {
            now = Date()
            boundary = 1.0 - now!.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        }
        let nowStamp = now!.rfc1123
        Thread.sleep(forTimeInterval: boundary - 0.01)
        let beforeStamp = Date().rfc1123
        Thread.sleep(forTimeInterval: 0.02)
        let afterStamp = Date().rfc1123
        
        XCTAssertEqual(nowStamp, beforeStamp)
        XCTAssertNotEqual(beforeStamp, afterStamp)
    }
    
    func testClientDefaultConfig() throws {
        let client = HTTPClient(on: self.eventLoopGroup)
        let res = try client.get("https://vapor.codes").wait()
        XCTAssertEqual(res.status, .ok)
    }
}


struct CookieError: Error { }

#if os(Linux)
let proxyHostname = "tinyproxy"
#else
let proxyHostname = "127.0.0.1"
#endif
