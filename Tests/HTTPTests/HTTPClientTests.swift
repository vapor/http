import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

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
        ("testURI", testURI),
    ]
}

