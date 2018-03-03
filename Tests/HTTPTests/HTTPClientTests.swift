import HTTP
import Foundation
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

    static let allTests = [
        ("testHTTPBin418", testHTTPBin418),
        ("testHTTPBinRobots", testHTTPBinRobots),
        ("testHTTPBinAnything", testHTTPBinAnything),
        ("testGoogleAPIsFCM", testGoogleAPIsFCM),
        ("testExampleCom", testExampleCom),
        ("testZombo", testZombo),
        ("testRomans", testRomans),
    ]
}

/// MARK: Utilities

func testFetchingURL(
    hostname: String,
    port: Int? = nil,
    path: String,
    times: Int = 3,
    responseContains: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    for i in 0..<times {
        do {
            let content = try fetchURLTCP(hostname: hostname, port: port ?? 80, path: path).wait()
            if content?.contains(responseContains) != true {
                XCTFail("Bad response \(i)/\(times): \(content ?? "nil")", file: file, line: line)
            }
        } catch {
            XCTFail("\(i)/\(times): \(error)", file: file, line: line)
        }
    }
}

func fetchURLTCP(hostname: String, port: Int, path: String) throws -> Future<String?> {
    return HTTPClient.connect(hostname: hostname, port: port).flatMap(to: HTTPResponse.self) { client in
        var req = HTTPRequest(method: .GET, url: URL(string: path)!, on: wrap(FakeLoop()))
        req.headers.replaceOrAdd(name: .host, value: hostname)
        req.headers.replaceOrAdd(name: .userAgent, value: "vapor/engine")
        return client.respond(to: req)
    }.map(to: String?.self) { res in
        return String(data: res.body.data ?? Data(), encoding: .ascii)
    }
}

final class FakeLoop: EventLoop {
    var inEventLoop: Bool {
        return true
    }

    func execute(_ task: @escaping () -> Void) {
        fatalError()
    }

    func scheduleTask<T>(in: TimeAmount, _ task: @escaping () throws -> (T)) -> Scheduled<T> {
        fatalError()
    }

    func shutdownGracefully(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void) {
        fatalError()
    }
}

//func fetchURLTLS(hostname: String, port: UInt16, path: String) throws -> String? {
//    let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
//    let tcpSocket = try TCPSocket(isNonBlocking: true)
//    let tcpClient = try TCPClient(socket: tcpSocket)
//    var settings = TLSClientSettings()
//    settings.peerDomainName = hostname
//    #if os(macOS)
//    let tlsClient = try AppleTLSClient(tcp: tcpClient, using: settings)
//    #else
//    let tlsClient = try OpenSSLClient(tcp: tcpClient, using: settings)
//    #endif
//    try tlsClient.connect(hostname: hostname, port: port)
//    let client = HTTPClient(
//        stream: tlsClient.socket.stream(on: eventLoop),
//        on: eventLoop
//    )
//    let req = HTTPRequest(method: .get, uri: URI(path: path), headers: [.host: hostname])
//    let res = try client.send(req).flatMap(to: Data.self) { res in
//        return res.body.makeData(max: 1_000_000)
//    }.await(on: eventLoop)
//    return String(data: res, encoding: .utf8)
//}

