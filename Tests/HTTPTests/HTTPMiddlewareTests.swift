import XCTest
@testable import HTTP
import Sockets

class HTTPMiddlewareTests: XCTestCase {
    static var allTests = [
        ("testClient", testClient),
        ("testClientDefault", testClientDefault),
        ("testServer", testServer),
    ]

    func testClient() throws {
        //let foo = FooMiddleware()
        let socket = try TCPInternetSocket(scheme: "http", hostname: "httpbin.org", port: 80)
        let client = try TCPClient(socket) // , [])
        let response = try client.respond(to: Request(method: .get, uri: "http://httpbin.org/headers"))

        // test to make sure http bin saw the 
        // header the middleware added
        XCTAssert(response.body.bytes?.makeString().contains("Foo") == true)
        XCTAssert(response.body.bytes?.makeString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")
    }

    func testClientDefault() throws {
//        let foo = FooMiddleware()
        // TCPClient.defaultMiddleware = [foo]

        let socket = try TCPInternetSocket(scheme: "http", hostname: "httpbin.org", port: 80)
        let client = try TCPClient(socket) // , [])
        let response = try client.respond(to: Request(method: .get, uri: "http://0.0.0.0/"))
        print(response)
        // test to make sure http bin saw the
        // header the middleware added
        XCTAssert(response.body.bytes?.makeString().contains("Foo") == true)
        XCTAssert(response.body.bytes?.makeString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")
    }

    func testServer() throws {
        let foo = FooMiddleware()

        // create a basic server that returns
        // request headers
        let socket = try TCPInternetSocket(scheme: "https", hostname: "0.0.0.0", port: 8244)
        let server = try TCPServer(socket)// , [foo])
        // let assignedPort = try server.server.stream.localAddress().port
        let responder = Request.Handler({ request in
            return request.headers.description.makeResponse()
        })

        // start the server in the background
        background {
            try! server.start(responder)
        }

        // create a basic client ot query the server
        let socket2 = try TCPInternetSocket(scheme: "https", hostname: "0.0.0.0", port: 8244)
        let client = try TCPClient(socket2) // , [])
        let response = try client.respond(to: Request(method: .get, uri: "http://0.0.0.0/"))

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(response.body.bytes?.makeString().contains("foo") == true)
        XCTAssert(response.body.bytes?.makeString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")

        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }
}


class FooMiddleware: Middleware {
    init() {}
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        print("FOO CALLED")
        request.headers["foo"] = "bar"
        let response = try next.respond(to: request)
        response.headers["bar"] = "baz"
        return response
    }
}
