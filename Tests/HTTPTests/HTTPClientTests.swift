import HTTP
import XCTest

class HTTPClientTests: XCTestCase {
    func testHTTPBin418() {
        testFetchingURL(hostname: "httpbin.org", path: "/status/418", responseContains: "[ teapot ]")
    }

    func testHTTPBinRobots() {
        testFetchingURL(hostname: "httpbin.org", path: "/robots.txt", responseContains: "Disallow: /deny")
    }

    func testHTTPBinAnything() {
        testFetchingURL(hostname: "httpbin.org", path: "/anything", responseContains: "http://httpbin.org/anything")
    }

    func testGoogleAPIsFCM() {
        testFetchingURL(hostname: "fcm.googleapis.com", path: "/fcm/send", responseContains: "<TITLE>Moved Temporarily</TITLE>")
    }

    func testExampleCom() {
        testFetchingURL(hostname: "example.com", path: "/", responseContains: "<title>Example Domain</title>")
    }

    func testZombo() {
        testFetchingURL(hostname: "zombo.com", path: "/", responseContains: "<title>ZOMBO</title>")
    }

    func testRomans() {
        testFetchingURL(hostname: "romansgohome.com", path: "/", responseContains: "Romans Go Home!")
    }

    func testAmazonWithTLS() {
        testFetchingURL(hostname: "www.amazon.com", port: 443, tls: true, path: "/", responseContains: "Amazon.com, Inc.")
    }

    static let allTests = [
        ("testHTTPBin418", testHTTPBin418),
        ("testHTTPBinRobots", testHTTPBinRobots),
        ("testHTTPBinAnything", testHTTPBinAnything),
        ("testGoogleAPIsFCM", testGoogleAPIsFCM),
        ("testExampleCom", testExampleCom),
        ("testZombo", testZombo),
        ("testRomans", testRomans),
        ("testAmazonWithTLS", testAmazonWithTLS),
    ]
}

/// MARK: Utilities

func testFetchingURL(
    hostname: String,
    port: Int? = nil,
    tls: Bool = false,
    path: String,
    times: Int = 3,
    responseContains: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    for i in 0..<times {
        do {
            var content: String?
            if tls {
                content = try fetchURLTCPWithTLS(hostname: hostname, port: port ?? 443, path: path).wait()
            } else {
                content = try fetchURLTCP(hostname: hostname, port: port ?? 80, path: path).wait()
            }
            if content?.contains(responseContains) != true {
                XCTFail("Bad response \(i)/\(times): \(content ?? "nil")", file: file, line: line)
            }
        } catch {
            XCTFail("\(i)/\(times): \(error)", file: file, line: line)
        }
    }
}

func fetchURLTCP(hostname: String, port: Int, path: String) throws -> Future<String?> {
    let loop = MultiThreadedEventLoopGroup(numThreads: 1).next()
    return HTTPClient.connect(hostname: hostname, port: port, on: loop).flatMap(to: HTTPResponse.self) { client in
        var req = HTTPRequest(method: .GET, url: URL(string: path)!)
        req.headers.replaceOrAdd(name: .host, value: hostname)
        req.headers.replaceOrAdd(name: .userAgent, value: "vapor/engine")
        return client.send(req)
    }.map(to: String?.self) { res in
        return String(data: res.body.data ?? Data(), encoding: .ascii)
    }
}

func fetchURLTCPWithTLS(hostname: String, port: Int, path: String) throws -> Future<String?> {
    let loop = MultiThreadedEventLoopGroup(numThreads: 1).next()
    return try HTTPClient.connectTLS(hostname: hostname, port: port, on: loop).flatMap(to: HTTPResponse.self) { client in
        var req = HTTPRequest(method: .GET, url: URL(string: path)!)
        req.headers.replaceOrAdd(name: .host, value: hostname)
        req.headers.replaceOrAdd(name: .userAgent, value: "vapor/engine")
        return client.send(req)
    }.map(to: String?.self) { res in
        return String(data: res.body.data ?? Data(), encoding: .ascii)
    }
}
