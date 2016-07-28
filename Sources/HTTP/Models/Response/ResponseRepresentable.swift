/**
    Any data structure that complies to this protocol
    can be returned to generic Vapor closures or route handlers.

    ```app.get("/") { request in
        return object //must be of type `ResponseRepresentable`
    }```
*/
public protocol ResponseRepresentable {
    func makeResponse(for request: Request) throws -> Response
}


///Allows responses to be returned through closures
extension Response: ResponseRepresentable {
    public func makeResponse(for request: Request) -> Response {
        return self
    }
}

///Allows Swift Strings to be returned through closures
extension Swift.String: ResponseRepresentable {
    public func makeResponse(for request: Request) -> Response {
        let data = self.utf8.array
        return Response(body: .data(data))
    }
}
