import Engine

func httpClient() throws {
    let response = try HTTPClient<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
    print(response)
}

func httpServer() throws {
    final class Responder: HTTPResponder {
        func respond(to request: HTTPRequest) throws -> HTTPResponse {
            let body = "Hello World".makeBody()
            return HTTPResponse(body: body)
        }
    }

    let server = try HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>(port: port)

    print("visit http://localhost:\(port)/")
    try server.start(responder: Responder()) { error in
        print("Got error: \(error)")
    }
}

try httpServer()
