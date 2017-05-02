extension Middleware {
    func chain(to responder: Responder) -> Responder {
        return BasicResponder { request, writer in
            let res = try self.respond(to: request, chainingTo: responder)
            try writer.write(res)
        }
    }
}

extension Collection where Iterator.Element == Middleware {
    func chain(to responder: Responder) -> Responder {
        return reversed().reduce(responder) { nextResponder, nextMiddleware in
            return BasicResponder { request, writer in
                let res = try nextMiddleware.respond(to: request, chainingTo: nextResponder)
                try writer.write(res)
            }
        }
    }
}
