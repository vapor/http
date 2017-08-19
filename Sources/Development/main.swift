import Core
import Dispatch
import Foundation
import HTTP
import TCP

let res = try Response(status: .ok, body: "hi")

struct Application: Responder {
    func respond(to req: Request, using writer: ResponseWriter) {
        writer.write(res)
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

server.error = { error in
    print(error)
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
