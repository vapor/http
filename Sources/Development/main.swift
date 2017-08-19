import Core
import Dispatch
import HTTP
import TCP

let server = try TCP.Server(port: 8080)

server.then { client in
    let parser = HTTP.RequestParser()

    client.map(parser.parse).map { request in
        return HTTP.Response(status: 200)
    }.then(client.send)
    
    return Future(client.listen)
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
