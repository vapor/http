import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

class HTTPClientTests: XCTestCase {
    func testTCP() throws {
        let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
        Thread.async { eventLoop.runLoop() }

        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        try tcpClient.connect(hostname: "httpbin.org", port: 80)
        let tcpSource = tcpSocket.source(on: eventLoop)
        let tcpSink = tcpSocket.sink(on: eventLoop)
        let client = HTTPClient(source: tcpSource, sink: tcpSink, worker: eventLoop)

        let req = HTTPRequest(method: .get, uri: "/html", headers: [.host: "httpbin.org"])
        let res = client.send(req)

        let exp = expectation(description: "response")
        res.flatMap(to: Data.self) { res in
            return res.body.makeData(max: 100_000)
        }.map(to: Void.self) { data in
            XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("Moby-Dick"))
            XCTAssertEqual(data.count, 3741)
            exp.fulfill()
        }.catch { error in
            XCTFail("\(error)")
        }

        waitForExpectations(timeout: 5) 
    }

    func testStream() throws {
        let eventLoop = try DefaultEventLoop(label: "codes.vapor.http.test.client")
        Thread.async { eventLoop.runLoop() }

        var dataRequest: ConnectionContext?
        var output: [Data] = []
        var parserStream: AnyInputStream<ByteBuffer>?

        let byteStream = ClosureStream<ByteBuffer>.init(
            onInput: { event in
                switch event {
                case .next(let buffer): output.append(Data(buffer))
                case .connect(let upstream): dataRequest = upstream
                case .error(let error): XCTFail("\(error)")
                case .close: print("closed")
                }
            },
            onOutput: { stream in
                parserStream = AnyInputStream(stream)
            },
            onConnection: { event in
                print(event)
            }
        )
        let client = HTTPClient(source: byteStream, sink: byteStream, worker: eventLoop)
        let req = HTTPRequest(method: .get, uri: "/html", headers: [.host: "httpbin.org"])
        let futureRes = client.send(req)

        XCTAssertEqual(output.count, 0)
        XCTAssertNotNil(dataRequest)
        dataRequest?.request()
        if output.count == 1 {
            let string = String(data: output[0], encoding: .utf8)!
            XCTAssertEqual(string, "GET /html HTTP/1.1\r\nHost: httpbin.org\r\nContent-Length: 0\r\n\r\n")
        } else {
            XCTFail("Invalid output count: \(output.count)")
        }

        "HTTP/1.1 137 TEST\r\nContent-Length: 0\r\n\r\n".data(using: .utf8)!.withByteBuffer(parserStream!.next)
        let res = try futureRes.blockingAwait(timeout: .seconds(5))
        XCTAssertEqual(res.status.code, 137)
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
        ("testStream", testStream),
        ("testURI", testURI),
    ]
}
