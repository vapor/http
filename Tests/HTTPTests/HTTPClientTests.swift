import Async
import Bits
import HTTP
import Foundation
import TCP
import TLS
import XCTest
#if os(Linux)
import OpenSSL
#else
import AppleTLS
#endif

class HTTPClientTests: XCTestCase {
    func testTCP() throws {
        let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
        let client = try HTTPClient.tcp(hostname: "httpbin.org", port: 80, on: eventLoop) { _, error in
            XCTFail("\(error)")
        }

        let req = HTTPRequest(method: .get, uri: "/html", headers: [.host: "httpbin.org"])
        let res = try client.send(req).flatMap(to: Data.self) { res in
            return res.body.makeData(max: 100_000)
        }.await(on: eventLoop)

        XCTAssert(String(data: res, encoding: .utf8)?.contains("Moby-Dick") == true)
        XCTAssertEqual(res.count, 3741)
    }
    
    func testConnectionClose() throws {
        let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
        let client = try HTTPClient.tcp(hostname: "httpbin.org", port: 80, on: eventLoop) { _, error in
            XCTFail("\(error)")
        }
        
        let req = HTTPRequest(method: .get, uri: "/status/418", headers: [.host: "httpbin.org"])
        let res = try client.send(req).flatMap(to: Data.self) { res in
            return res.body.makeData(max: 100_000)
        }.await(on: eventLoop)
        
        XCTAssertEqual(res.count, 135)
    }

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

    /// TLS

    func testHTTPBin418Secure() {
        testFetchingURL(hostname: "httpbin.org", path: "/status/418", useTLS: true, responseContains: "[ teapot ]")
    }

    func testHTTPBinRobotsSecure() {
        testFetchingURL(hostname: "httpbin.org", path: "/robots.txt", useTLS: true, responseContains: "Disallow: /deny")
    }

    func testHTTPBinAnythingSecure() {
        testFetchingURL(hostname: "httpbin.org", path: "/anything", useTLS: true, responseContains: "https://httpbin.org/anything")
    }

    func testGoogleAPIsFCMSecure() {
        testFetchingURL(hostname: "fcm.googleapis.com", path: "/fcm/send", useTLS: true, responseContains: "<TITLE>Moved Temporarily</TITLE>")
    }
    
    func testURI() {
        var uri: URI = "http://localhost:8081/test?q=1&b=4#test"
        XCTAssertEqual(uri.scheme, "http")
        XCTAssertEqual(uri.hostname, "localhost")
        XCTAssertEqual(uri.port, 8081)
        XCTAssertEqual(uri.path, "/test")
        XCTAssertEqual(uri.query, "q=1&b=4")
        XCTAssertEqual(uri.fragment, "test")
    }

    static let allTests = [
        ("testTCP", testTCP),
        ("testHTTPBin418", testHTTPBin418),
        ("testHTTPBinRobots", testHTTPBinRobots),
        ("testHTTPBinAnything", testHTTPBinAnything),
        ("testGoogleAPIsFCM", testGoogleAPIsFCM),
        ("testExampleCom", testExampleCom),
        ("testZombo", testZombo),
        ("testRomans", testRomans),
        ("testHTTPBin418Secure", testHTTPBin418Secure),
        ("testHTTPBinRobotsSecure", testHTTPBinRobotsSecure),
        ("testHTTPBinAnythingSecure", testHTTPBinAnythingSecure),
        ("testGoogleAPIsFCMSecure", testGoogleAPIsFCMSecure),
        ("testURI", testURI),
    ]
}

/// MARK: Utilities

func testFetchingURL(
    hostname: String,
    port: UInt16? = nil,
    path: String,
    useTLS: Bool = false,
    times: Int = 3,
    responseContains: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    #if os(Linux)
    /// FIXME: TLS not working on Linux yet
    if useTLS {
        return
    }
    #endif
    for i in 0..<times {
        do {
            let content: String?
            if useTLS {
                content = try fetchURLTLS(hostname: hostname, port: port ?? 443, path: path)
            } else {
                content = try fetchURLTCP(hostname: hostname, port: port ?? 80, path: path)
            }
            if content?.contains(responseContains) != true {
                XCTFail("Bad response \(i)/\(times): \(content ?? "nil")", file: file, line: line)
            }
        } catch {
            XCTFail("\(i)/\(times): \(error)", file: file, line: line)
        }
    }
}

func fetchURLTCP(hostname: String, port: UInt16, path: String) throws -> String? {
    let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
    let client = try HTTPClient.tcp(hostname: hostname, port: port, on: eventLoop) { _, error in
        XCTFail("\(error)")
    }

    let req = HTTPRequest(method: .get, uri: URI(path: path), headers: [.host: hostname])
    let res = try client.send(req).flatMap(to: Data.self) { res in
        return res.body.makeData(max: 1_000_000)
    }.await(on: eventLoop)

    return String(data: res, encoding: .utf8)
}

func fetchURLTLS(hostname: String, port: UInt16, path: String) throws -> String? {
    let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
    let tcpSocket = try TCPSocket(isNonBlocking: true)
    let tcpClient = try TCPClient(socket: tcpSocket)
    var settings = TLSClientSettings()
    settings.peerDomainName = hostname
    #if os(macOS)
    let tlsClient = try AppleTLSClient(tcp: tcpClient, using: settings)
    #else
    let tlsClient = try OpenSSLClient(tcp: tcpClient, using: settings)
    #endif
    try tlsClient.connect(hostname: hostname, port: port)
    let client = HTTPClient(
        stream: tlsClient.socket.stream(on: eventLoop),
        on: eventLoop
    )
    let req = HTTPRequest(method: .get, uri: URI(path: path), headers: [.host: hostname])
    let res = try client.send(req).flatMap(to: Data.self) { res in
        return res.body.makeData(max: 1_000_000)
    }.await(on: eventLoop)
    return String(data: res, encoding: .utf8)
}
