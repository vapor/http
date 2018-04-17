import Async
import HTTP
import Foundation

let hostname = "localhost"
let port: Int = 8123

let res = HTTPResponse(body: HTTPBody(string: "Hello, world!"))

struct EchoResponder: HTTPServerResponder {
    func respond(to req: HTTPRequest, on worker: Worker) -> Future<HTTPResponse> {
        return Future.map(on: worker) { res }
    }
}

print("Server starting on http://\(hostname):\(port)")
let group = MultiThreadedEventLoopGroup(numThreads: System.coreCount)
let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
try server.onClose.wait()
