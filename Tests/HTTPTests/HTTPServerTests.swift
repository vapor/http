import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

struct EchoResponder: HTTPResponder {
    init() {}

    func respond(to req: HTTPRequest, on Worker: Worker) throws -> Future<HTTPResponse> {
        /// simple echo server
        return Future(.init(body: req.body))
    }
}

class HTTPServerTests: XCTestCase {
    func testTCP() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpServer = try TCPServer(socket: tcpSocket)

        // beyblades let 'er rip
        try tcpServer.start(hostname: "localhost", port: 8123, backlog: 128)

        let echo = EchoResponder()

        for i in 1...ProcessInfo.processInfo.activeProcessorCount {
            let worker = try DefaultEventLoop(label: "codes.vapor.test.worker.\(i)")
            let serverStream = tcpServer.stream(on: worker)

            let server = HTTPServer(
                acceptStream: serverStream,
                worker: worker,
                responder: echo
            )
            print(server)

            Thread.async {
                worker.runLoop()
            }
        }

//        let group = DispatchGroup()
//        group.enter()
//        group.wait()
//        
        let exp = expectation(description: "all requests complete")
        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = try TCPClient(socket: clientSocket)
            try client.connect(hostname: "localhost", port: 8123)
            let write = Data("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n".utf8)
            _ = try client.socket.write(write)
            let read = try client.socket.read(max: 512)
            client.close()
            let string = String(data: read, encoding: .utf8)
            XCTAssertEqual(string, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            num -= 1
            if num == 0 {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
        tcpServer.stop()
    }

    static let allTests = [
        ("testTCP", testTCP),
    ]
}
