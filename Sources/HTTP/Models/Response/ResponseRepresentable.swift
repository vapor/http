/**
    Any data structure that complies to this protocol
    can be returned to generic Vapor closures or route handlers.

    ```app.get("/") { request in
        return object //must be of type `ResponseRepresentable`
    }```
*/
public protocol HTTPResponseRepresentable {
    func makeResponse(for request: HTTPRequest) throws -> HTTPResponse
}


///Allows responses to be returned through closures
extension HTTPResponse: HTTPResponseRepresentable {
    public func makeResponse(for request: HTTPRequest) -> HTTPResponse {
        return self
    }
}

///Allows Swift Strings to be returned through closures
extension Swift.String: HTTPResponseRepresentable {
    public func makeResponse(for request: HTTPRequest) -> HTTPResponse {
        let data = self.utf8.array
        return HTTPResponse(body: .data(data))
    }
}
