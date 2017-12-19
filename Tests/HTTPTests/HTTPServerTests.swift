import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

struct EchoWorker: HTTPResponder, Worker {
    let eventLoop: EventLoop = DispatchEventLoop(label: "codes.vapor.http.test.server.worker")

    func respond(to req: HTTPRequest, on Worker: Worker) throws -> Future<HTTPResponse> {
        /// simple echo server
        return Future(.init(body: req.body))
    }
}

class HTTPServerTests: XCTestCase {
    func testTCP() throws {
        let accept = DispatchEventLoop(label: "codes.vapor.http.test.server.accept")
        let workers = [
            EchoWorker(),
            EchoWorker(),
            EchoWorker(),
            EchoWorker(),
            EchoWorker(),
            EchoWorker(),
            EchoWorker(),
            EchoWorker()
        ]

        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpServer = try TCPServer(socket: tcpSocket)
        let server = HTTPServer<TCPClientStream, EchoWorker>(
            acceptStream: tcpServer.stream(on: accept),
            workers: workers
        )
        server.onError = { XCTFail("\($0)") }

        let acceptItem = DispatchWorkItem(block: accept.run)
        let workerItems = workers.map { DispatchWorkItem(block: $0.eventLoop.run) }

        DispatchQueue.global().async(execute: acceptItem)
        workerItems.forEach { DispatchQueue.global().async(execute: $0) }

        // beyblades let 'er rip
        try tcpServer.start(hostname: "localhost", port: 8123, backlog: 128)
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

        acceptItem.cancel()
        workerItems.forEach { $0.cancel() }
        tcpServer.stop()
    }

    static let allTests = [
        ("testTCP", testTCP),
    ]
}
