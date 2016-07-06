public protocol RouteBuilder {
    var leadingPath: String { get }
    var scopedMiddleware: [Middleware] { get }

    func add(
        middleware: [Middleware],
        method: Method,
        path: String,
        handler: Route.Handler
    )
}

extension RouteBuilder {
    public func add(
        _ method: Method,
        path: String,
        handler: Route.Handler
    ) {
        add(middleware: [], method: method, path: path, handler: handler)
    }
}

extension RouteBuilder {
    public var leadingPath: String { return "" }
    public var scopedMiddleware: [Middleware] { return [] }
}

extension RouteBuilder {
    public func grouped(_ path: String) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: path,
            scopedMiddleware: scopedMiddleware
        )
    }

    public func grouped(_ path: String, _ body: @noescape (group: Route.Link) -> Void) {
        let group = grouped(path)
        body(group: group)
    }

    public func grouped(_ middlewares: Middleware...) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: nil,
            scopedMiddleware: scopedMiddleware + middlewares
        )
    }

    public func grouped(_ middlewares: [Middleware]) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: nil,
            scopedMiddleware: scopedMiddleware + middlewares
        )
    }

    public func grouped(_ middlewares: Middleware..., _ body: @noescape (group: Route.Link) -> Void) {
        let groupObject = grouped(middlewares)
        body(group: groupObject)
    }

    public func grouped(middleware middlewares: [Middleware], _ body: @noescape (group: Route.Link) -> Void) {
        let groupObject = grouped(middlewares)
        body(group: groupObject)
    }
}

extension Middleware {
    func chain(to responder: Responder) -> Responder {
        return Request.Handler { request in
            return try self.respond(to: request, chainingTo: responder)
        }
    }
}

extension Collection where Iterator.Element == Middleware {
    func chain(to responder: Responder) -> Responder {
        return reversed().reduce(responder) { nextResponder, nextMiddleware in
            return Request.Handler { request in
                return try nextMiddleware.respond(to: request, chainingTo: nextResponder)
            }
        }
    }
}
