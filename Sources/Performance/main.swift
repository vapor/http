import Async
import HTTP
import TCP
import Foundation

let tcpSocket = try TCPSocket(isNonBlocking: true)
let tcpServer = try TCPServer(socket: tcpSocket)

let hostname = "localhost"
let port: UInt16 = 8123
try tcpServer.start(hostname: hostname, port: port, backlog: 128)


struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest, on Worker: Worker) throws -> Future<HTTPResponse> {
        return Future(.init(body: req.body))
    }
}

let workerCount = ProcessInfo.processInfo.activeProcessorCount
for i in 1...workerCount {
    let loop = try DefaultEventLoop(label: "codes.vapor.engine.performance.\(i)")
    let serverStream = tcpServer.stream(on: loop)

    _ = HTTPServer(
        acceptStream: serverStream.map(to: TCPSocketStream.self) {
            $0.socket.stream(on: loop) { sink, error in
                print("[Error] \(error)")
            }
        },
        worker: loop,
        responder: EchoResponder()
    )

    print("Starting worker #\(i) on \(hostname):\(port)")
    if i == workerCount {
        loop.runLoop()
    } else {
        Thread.async { loop.runLoop() }
    }
}
