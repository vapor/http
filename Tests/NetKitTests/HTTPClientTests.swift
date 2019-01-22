import NetKit
import XCTest

class HTTPClientTests: XCTestCase {
    func testHTTPBin418() throws {
        try testURL("http://httpbin.org/status/418", contains: "[ teapot ]")
    }

    func testHTTPBinRobots() throws {
        try testURL("http://httpbin.org/robots.txt", contains: "Disallow: /deny")
    }

    func testHTTPBinAnything() throws {
        try testURL("http://httpbin.org/anything", contains: "http://httpbin.org/anything")
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

    func testQuery() throws {
        try testURL("http://httpbin.org/get?foo=bar", contains: "bar")
    }
}

// MARK: Private

private func testURL(_ string: String, times: Int = 3, contains: String) throws {
    try testURL(string, times: times) { res in
        let string = String(data: res.body.data ?? Data(), encoding: .ascii) ?? ""
        if string.contains(contains) != true {
            throw HTTPError(identifier: "badResponse", reason: "Bad response: \(string)")
        }
    }
}

private func testURL(
    _ string: String,
    times: Int = 3,
    check: (HTTPResponse) throws -> ()
) throws {
    guard let url = URL(string: string) else {
        throw HTTPError(identifier: "parseURL", reason: "Could not parse URL: \(string)")
    }
    let tlsConfig: TLSConfiguration? = (url.scheme == "https" ? .forClient(certificateVerification: .none) : nil)
    let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    for _ in 0..<times {
        let res = try HTTPClientConnection.connect(
            hostname: url.host ?? "",
            tlsConfig: tlsConfig,
            on: worker
        ).flatMap { client -> EventLoopFuture<HTTPResponse> in
            var comps =  URLComponents()
            comps.path = url.path.isEmpty ? "/" : url.path
            comps.query = url.query
            let req = HTTPRequest(method: .GET, url: comps.url ?? .root)
            return client.send(req)
        }.wait()
        try check(res)
    }
    try worker.syncShutdownGracefully()
}
