import Foundation

let portArgument = ProcessInfo.processInfo()
    .arguments
    .lazy
    .filter { $0.hasPrefix("--port=") }
    .first?
    .characters
    .dropFirst("--port=".characters.count)

let port = Int(String(portArgument)) ?? 8080

import Engine

func client() throws {
    let response = try HTTPClient<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
    print(response)
}

func server() throws {
    final class Responder: HTTPResponder {
        func respond(to request: Request) throws -> Response {
            print(request)
            let body = "Hello World".makeBody()
            return Response(body: body)
        }
    }

    let server = try HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>(port: port)

    print("visit http://localhost:\(port)/")
    try server.start(responder: Responder()) { error in
        print("Got error: \(error)")
    }
}

try server()
