import Core
import Dispatch
import Foundation
import HTTP
import TCP

struct Application: Responder {
    func respond(to req: Request, using writer: ResponseWriter) throws {
        let res = try Response(status: .ok, body: "hi")
        try writer.write(res)
    }
}

let app = Application()
let server = try TCP.Server(port: 8080)

server.consume { client in
    let parser = HTTP.RequestParser()
    let serializer = HTTP.ResponseSerializer()

    client.stream(to: parser)
        .stream(to: app.makeStream())
        .stream(to: serializer)
        .consume(into: client)

    client.listen()
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
