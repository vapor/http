import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testServer() {
        do {
            try _testServer()
        } catch {
            XCTFail("\(error)")
        }
    }
    func _testServer() throws {
        let serverSocket = try TCPSocket(isNonBlocking: true)
        let server = try TCPServer(socket: serverSocket)

        let workerLoop = try DefaultEventLoop(label: "codes.vapor.test.worker.1")
        // let serverLoop = try DefaultEventLoop(label: "codes.vapor.test.server")
        let serverStream = server.stream(on: workerLoop)


        /// set up the server stream
        serverStream.drain { req in
            req.request(count: .max)
        }.output { client in
            let clientSource = client.socket.source(on: workerLoop)
            let clientSink = client.socket.sink(on: workerLoop)
            clientSource.output(to: clientSink)
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // closed
        }

        // beyblades let 'er rip
        try server.start(port: 8338)
        Thread.async { workerLoop.runLoop() }
        // Thread.async { serverLoop.runLoop() }
        // serverLoop.runLoop()

        let exp = expectation(description: "all requests complete")
        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = try TCPClient(socket: clientSocket)
            try client.connect(hostname: "localhost", port: 8338)
            let write = Data("hello".utf8)
            _ = try client.socket.write(write)
            let read = try client.socket.read(max: 512)
            client.close()
            XCTAssertEqual(read, write)
            num -= 1
            if num == 0 {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
        server.stop()
    }

    static let allTests = [
        ("testServer", testServer),
    ]
}
