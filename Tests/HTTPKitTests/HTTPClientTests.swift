import HTTPKit
import XCTest

class HTTPClientTests: XCTestCase {
    func testHTTPBin418() throws {
        try testURL("http://httpbin.org/status/418", contains: "[ teapot ]")
    }

    func testHTTPBinRobots() throws {
        try testURL("http://httpbin.org/robots.txt", contains: "Disallow: /deny")
    }

    func testHTTPBinAnything() throws {
        try testURL("http://httpbin.org/anything", contains: "://httpbin.org/anything")
    }

    func testGoogleAPIsFCM() throws {
        try testURL("http://fcm.googleapis.com/fcm/send", contains: "<TITLE>Moved Temporarily</TITLE>")
    }

    func testExampleCom() throws {
        try testURL("http://example.com", contains: "<title>Example Domain</title>")
    }

    func testZombo() throws {
        try testURL("http://zombo.com", contains: "<title>ZOMBO</title>")
    }

    func testVaporWithTLS() throws {
        try testURL("https://vapor.codes", contains: "Server-side Swift")
    }
    
    func testGoogleWithTLS() throws {
        try testURL("https://www.google.com/search?q=vapor+swift", contains: "web framework")
    }
    
    func testSNIWebsite() throws {
        try testURL("https://chrismeller.com", contains: "Chris")
    }

    func testQuery() throws {
        try testURL("http://httpbin.org/get?foo=bar", contains: "bar")
    }
    
    func testClientDefaultConfig() throws {
        let client = HTTPClient(on: self.eventLoopGroup)
        let res = try client.get("https://vapor.codes").wait()
        XCTAssertEqual(res.status, .ok)
    }
    
    func testRemotePeer() throws {
        let client = HTTPClient(on: self.eventLoopGroup)
        let httpReq = HTTPRequest(method: .GET, url: "http://vapor.codes/")
        let httpRes = try client.send(httpReq).wait()
        // TODO: how to get access to channel?
        // XCTAssertEqual(httpRes.remotePeer(on: client.channel).port, 80)
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
    
    var eventLoopGroup: EventLoopGroup!
    
    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }
}

// MARK: Private

#if DOCKER
private let proxyHostname = "tinyproxy"
#else
private let proxyHostname = "127.0.0.1"
#endif

private func testURL(_ string: String, times: Int = 3, contains: String) throws {
    try testURL(string, times: times) { res in
        let string = String(data: res.body.data ?? Data(), encoding: .ascii) ?? ""
        if string.contains(contains) != true {
            throw TestError(string)
        }
    }
}

struct TestError: Error {
    let string: String
    init(_ string: String) {
        self.string = string
    }
}

private func testURL(
    _ string: String,
    times: Int = 3,
    check: (HTTPResponse) throws -> ()
) throws {
    let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    for _ in 0..<times {
        let tlsConfig: TLSConfiguration
        tlsConfig = .forClient()
        let res = try HTTPClient(
            config: .init(tlsConfig: tlsConfig),
            on: worker
        ).get(string).wait()
        try check(res)
    }
    try worker.syncShutdownGracefully()
}
