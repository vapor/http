import Engine

func client() throws {
    let response = try HTTPClient<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
    print(response)
}

func server() throws {
    final class Responder: HTTPResponder {
        func respond(to request: Request) throws -> Response {
            let body = "Hello World".makeBody()
            return Response(body: body)
        }
    }

    let server = try HTTPServer()
    try server.start(responder: Responder(), errors: { _ in })
}

try client()
