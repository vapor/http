import Core
import Dispatch
import HTTP
import TCP

let server = try TCP.Server(port: 8080)

server.process { client in
    let parser = HTTP.RequestParser()

    client.map(parser.parse).map { request in
        return HTTP.Response(status: .ok, body: "hi")
    }.process(using: client.send)
    
    client.listen()
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
