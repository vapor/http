import Engine
import WebSockets

func client() throws {
    let response = try HTTPClient<TCPClientStream>.get("https://api.spotify.com/v1/search?q=beyonce&type=artist")
    print(response.body.bytes?.string)
}

func server() throws {
    final class Responder: HTTPResponder {
        func respond(to request: Request) throws -> Response {
            let body = "Hello World".makeBody()
            return Response(body: body)
        }
    }

    let server = try HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>()
    try server.start(responder: Responder(), errors: { _ in })
}

// Call

try server()
