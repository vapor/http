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

    func testAmazonWithTLS() throws {
        try testURL("https://www.amazon.com", contains: "Amazon.com, Inc.")
    }

    func testQuery() throws {
        try testURL("http://httpbin.org/get?foo=bar", contains: "bar")
    }
    
    func testClientHostHeaderPortSpecification() throws {
        
        class Responder: HTTPServerResponder {
            
            init(promise: Promise<Bool>) {
                self.promise = promise
            }
            
            let promise: Promise<Bool>
            func respond(to request: HTTPRequest, on worker: Worker) -> EventLoopFuture<HTTPResponse> {
                let host = request.headers.firstValue(name: HTTPHeaderName.host)!
                promise.succeed(result: host.hasSuffix(":5000"))
                return worker.future().map {
                    return HTTPResponse(status: .ok)
                }
            }
        }
        
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let promise = worker.next().newPromise(of: Bool.self)
        let responder = Responder(promise: promise)
        let _ = try HTTPServer.start(hostname: "localhost", port: 5000, responder: responder, on: worker).wait()
        let client = try HTTPClient.connect(hostname: "localhost", port: 5000, on: worker).wait()
        let _ = try client.send(HTTPRequest(url: "/")).wait()
        XCTAssertTrue(try promise.futureResult.wait(), "Client didn't add port to Host header")
        
    }

    static let allTests = [
        ("testHTTPBin418", testHTTPBin418),
        ("testHTTPBinRobots", testHTTPBinRobots),
        ("testHTTPBinAnything", testHTTPBinAnything),
        ("testGoogleAPIsFCM", testGoogleAPIsFCM),
        ("testExampleCom", testExampleCom),
        ("testZombo", testZombo),
        ("testAmazonWithTLS", testAmazonWithTLS),
        ("testQuery", testQuery),
        ("testClientHostHeaderPortSpecification", testClientHostHeaderPortSpecification)
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

private func testURL(
    _ string: String,
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
            let req = HTTPRequest(method: .GET, url: comps.url ?? .root)
            return client.send(req)
        }.wait()
        try check(res)
    }
}
