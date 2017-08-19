import Core
import Dispatch
import Foundation
import HTTP
import TCP

let server = try TCP.Server(port: 8080)

server.process { client in
    let parser = HTTP.RequestParser()
    let serializer = HTTP.ResponseSerializer()

    client.map(parser.parse).map { request in
        return try! HTTP.Response(status: .ok, body: "hi")
    }.map(serializer.serialize).process(using: client.write)
    
    client.listen()
}

try server.start()

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
