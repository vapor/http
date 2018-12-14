import NIO
import NIOHTTP1
import HTTP
import XCTest

class HTTPTests: XCTestCase {
    func testCookieParse() throws {
        /// from https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
        guard let (name, value) = HTTPCookieValue.parse("id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
        }
        XCTAssertEqual(name, "id")
        XCTAssertEqual(value.string, "a3fWa")
        XCTAssertEqual(value.expires, Date(rfc1123: "Wed, 21 Oct 2015 07:28:00 GMT"))
        XCTAssertEqual(value.isSecure, true)
        XCTAssertEqual(value.isHTTPOnly, true)
        
        guard let cookie: (name: String, value: HTTPCookieValue) = HTTPCookieValue.parse("vapor=; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
        }
        XCTAssertEqual(cookie.name, "vapor")
        XCTAssertEqual(cookie.value.string, "")
        XCTAssertEqual(cookie.value.isSecure, true)
        XCTAssertEqual(cookie.value.isHTTPOnly, true)
    }
    
    func testCookieIsSerializedCorrectly() throws {
        let httpReq = HTTPRequest(method: .GET, url: "/")

        guard let (name, value) = HTTPCookieValue.parse("id=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
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
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client = try HTTPClient.connect(
            config: .init(hostname: "httpbin.org", eventLoop: worker.next())
        ).wait()
        let httpReq = HTTPRequest(method: .GET, url: "/")
        let httpRes = try client.respond(to: httpReq).wait()
        XCTAssertEqual(httpRes.remotePeer.port, 80)
    }
    
    func testLargeResponseClose() throws {
        struct LargeResponder: HTTPResponder {
            func respond(to request: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
                let res = HTTPResponse(
                    status: .ok,
                    body: String(repeating: "0", count: 2_000_000)
                )
                return request.channel!.eventLoop.makeSucceededFuture(result: res)
            }
        }
        let server = try HTTPServer.start(
            config: .init(
                hostname: "localhost",
                port: 8080,
                errorHandler: { error in
                    XCTFail("\(error)")
                }
            ),
            responder: LargeResponder()
        ) .wait()
        
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client = try HTTPClient.connect(
            config: .init(hostname: "localhost", port: 8080, eventLoop: worker.next())
        ).wait()
        let req = HTTPRequest(method: .GET, url: "/")
        req.headers.replaceOrAdd(name: .connection, value: "close")
        let res = try client.respond(to: req).wait()
        XCTAssertEqual(res.body.count, 2_000_000)
        try server.close().wait()
        try server.onClose.wait()
    }
    
    func testUpgradeFail() throws {
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        struct FakeUpgrader: HTTPClientProtocolUpgrader {
            typealias UpgradeResult = String
            
            func buildUpgradeRequest() -> HTTPRequestHead {
                return .init(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
            }
            
            func isValidUpgradeResponse(_ upgradeResponse: HTTPResponseHead) -> Bool {
                return true
            }
            
            func upgrade(ctx: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<String> {
                return ctx.eventLoop.makeSucceededFuture(result: "hello")
            }
            
            
        }
        do {
            _ = try HTTPClient.upgrade(hostname: "foo", upgrader: FakeUpgrader(), on: worker.next()).wait()
            XCTFail("expected error")
        } catch {
            XCTAssert(error is NIOConnectionError)
        }
    }

    static let allTests = [
        ("testCookieParse", testCookieParse),
        ("testAcceptHeader", testAcceptHeader),
        ("testRemotePeer", testRemotePeer),
        ("testCookieIsSerializedCorrectly", testCookieIsSerializedCorrectly),
        ("testLargeResponseClose", testLargeResponseClose),
        ("testUpgradeFail", testUpgradeFail),
    ]
}
