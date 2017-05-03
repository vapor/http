import HTTP
import Sockets

let socket = try TCPInternetSocket(
    scheme: "http",
    hostname: "0.0.0.0",
    port: 8123
)


let server = try TCPServer(socket)
let responder = BasicResponder { req in
    return Response(status: .ok, body: "Hello world: \(req.uri.path)".makeBytes())
}

print("Server starting on \(server.scheme)://\(server.hostname):\(server.port)")
try server.start(responder) { error in
    print(error)
}

/*

let asyncServer = TCPAsyncServer(socket)
let asyncResponder = BasicAsyncResponder { req, writer in
    let res = Response(status: .ok, body: "Hello world: \(req.uri.path)".makeBytes())
    try writer.write(res)
}

print("Async server starting on \(server.scheme)://\(server.hostname):\(server.port)")
try asyncServer.start(responder) { error in
    print(error)
}

*/
