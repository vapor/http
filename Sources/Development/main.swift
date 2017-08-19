import Core
import Dispatch
import Foundation
import HTTP
import TCP

let res = try Response(status: .ok, body: "hi")

final class Application: Core.Stream {
    typealias Input = Request
    typealias Output = Response

    var output: OutputHandler?

    func input(_ input: Request) throws {
        try output?(res)
    }

}

let server = try TCP.Server(port: 8080)

server.consume { client in
    let app = Application()
    let parser = HTTP.RequestParser()
    let serializer = HTTP.ResponseSerializer()

    client.stream(to: parser)
        .stream(to: app)
        .stream(to: serializer)
        .consume(into: client)

    client.listen()
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
