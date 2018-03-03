import Async
import HTTP
import Foundation

let hostname = "localhost"
let port: Int = 8123

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest, on worker: Worker) -> Future<HTTPResponse> {
        let body: HTTPBody

        if req.url.path == "/chunked" {
            let stream = HTTPChunkedStream(on: worker)
            body = HTTPBody(chunked: stream)

            var buffer = ByteBufferAllocator().buffer(capacity: 256)
            buffer.write(string: "hello")
            stream.write(.chunk(buffer)).flatMap(to: Void.self) {
                buffer.clear()
                buffer.write(string: "world")
                return stream.write(.chunk(buffer))
            }.flatMap(to: Void.self) {
                buffer.clear()
                buffer.write(string: "!")
                return stream.write(.chunk(buffer))
            }.flatMap(to: Void.self) {
                return stream.write(.end)
            }.do {
                print("done")
            }.catch { error in
                print("error: \(error)")
            }
        } else {
            body = HTTPBody(string: "Hello, world!")
        }

        return Future.map(on: worker) {
            return HTTPResponse(body: body)
        }
    }
}

print("Server starting on http://\(hostname):\(port)")
let group = MultiThreadedEventLoopGroup(numThreads: 1)
let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
try server.onClose.wait()
