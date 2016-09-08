import XCTest
@testable import HTTP

class HTTPMiddlewareTests: XCTestCase {
    static var allTests = [
        ("testClient", testClient),
        ("testClientDefault", testClientDefault),
        ("testServer", testServer),
    ]

    func testClient() throws {
        let foo = FooMiddleware()
        let client = try BasicClient(scheme: "http", host: "httpbin.org", port: 80, securityLayer: .none, middleware: [foo])
        let response = try client.request(.get, path: "headers")

        // test to make sure http bin saw the 
        // header the middleware added
        XCTAssert(response.body.bytes?.string.contains("Foo") == true)
        XCTAssert(response.body.bytes?.string.contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")
    }

    func testClientDefault() throws {
        let foo = FooMiddleware()
        BasicClient.defaultMiddleware = [foo]

        let response = try BasicClient.get("http://httpbin.org/headers")

        // test to make sure http bin saw the
        // header the middleware added
        XCTAssert(response.body.bytes?.string.contains("Foo") == true)
        XCTAssert(response.body.bytes?.string.contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")
    }

    func testServer() throws {
        let foo = FooMiddleware()

        // create a basic server that returns
        // request headers
        let server = try BasicServer(host: "0.0.0.0", port: 8080, securityLayer: .none, middleware: [foo])
        let responder = Request.Handler({ request in
            return request.headers.description.makeResponse()
        })

        // start the server in the background
        try background {
            try! server.start(responder: responder, errors: { error in })
        }

        // create a basic client ot query the server
        let client = try BasicClient(scheme: "http", host: "0.0.0.0", port: 8080, securityLayer: .none, middleware: [])
        let response = try client.request(.get, path: "/foo")

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(response.body.bytes?.string.contains("foo") == true)
        XCTAssert(response.body.bytes?.string.contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(response.headers["bar"], "baz")
    }
}

class FooMiddleware: Middleware {
    init() {}
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        request.headers["foo"] = "bar"
        let response = try next.respond(to: request)
        response.headers["bar"] = "baz"
        return response
    }
}
