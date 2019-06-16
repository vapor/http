import HTTP
import XCTest

class HTTPClientTests: XCTestCase {
    func testHTTPBin418() throws {
        try testURL("http://httpbin.org/status/418", contains: "[ teapot ]")
    }

    func testHTTPBinRobots() throws {
        try testURL("http://httpbin.org/robots.txt", contains: "Disallow: /deny")
    }

    func testHTTPBinAnything() throws {
        try testURL("http://httpbin.org/anything", contains: "httpbin.org/anything")
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

    func testGoogleWithTLS() throws {
        try testURL("https://www.google.com/search?q=vapor+swift", contains: "web framework")
    }
    
    func testSNIWebsite() throws {
        try testURL("https://chrismeller.com", contains: "Chris")
    }

    func testQuery() throws {
        try testURL("http://httpbin.org/get?foo=bar", contains: "bar")
    }
    
    func testHeaderDecoration() throws {
        try testHeaders(sentHeaders: [:],
                        expectedHeaders: [("Host", "httpbin.org"),
                                          ("User-Agent", HTTPClient.defaultUserAgent)])
        try testHeaders(sentHeaders: ["Host": "hostb",
                                      "User-Agent": "foobar"],
                        expectedHeaders: [("Host", "hostb"),
                                          ("User-Agent", "foobar")])
    }

    static let allTests = [
        ("testHTTPBin418", testHTTPBin418),
        ("testHTTPBinRobots", testHTTPBinRobots),
        ("testHTTPBinAnything", testHTTPBinAnything),
        ("testGoogleAPIsFCM", testGoogleAPIsFCM),
        ("testExampleCom", testExampleCom),
        ("testZombo", testZombo),
        ("testGoogleWithTLS", testGoogleWithTLS),
        ("testSNIWebsite", testSNIWebsite),
        ("testQuery", testQuery),
        ("testHeaderDecoration", testHeaderDecoration),
    ]
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

private func testHeaders(
    times: Int = 3,
    sentHeaders: HTTPHeaders,
    expectedHeaders: [(String, String)]) throws {
    try testURL("https://httpbin.org/anything", headers: sentHeaders, times: times) { res in
        let string = String(data: res.body.data ?? Data(), encoding: .ascii) ?? ""
        for headerPair in expectedHeaders {
            XCTAssertTrue(string.contains("\"\(headerPair.0)\": \"\(headerPair.1)\""))
        }
    }
}

private func testURL(
    _ string: String,
    headers: HTTPHeaders = [:],
    times: Int = 3,
    check: (HTTPResponse) throws -> ()
) throws {
    guard let url = URL(string: string) else {
        throw HTTPError(identifier: "parseURL", reason: "Could not parse URL: \(string)")
    }
    let scheme: HTTPScheme = url.scheme == "https" ? .https : .http
    let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    for _ in 0..<times {
        let res = try HTTPClient.connect(scheme: scheme, hostname: url.host ?? "", on: worker).flatMap(to: HTTPResponse.self) { client in
            var comps =  URLComponents()
            comps.path = url.path.isEmpty ? "/" : url.path
            comps.query = url.query
            let req = HTTPRequest(method: .GET, url: comps.url ?? .root, headers: headers)
            return client.send(req)
        }.wait()
        try check(res)
    }
}
