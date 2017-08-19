import Core

public protocol Responder {
    func respond(to req: Request, using writer: ResponseWriter) throws
}

extension Responder {
    public func makeStream() -> ResponderStream<Self> {
        return ResponderStream(self)
    }
}

// MARK: Writer

public protocol ResponseWriter {
    func write(_ response: Response) throws
}

extension ResponseWriter {
    public func write(_ response: ResponseRepresentable) throws {
        return try write(response.makeResponse())
    }
}

// MARK: Stream

public final class ResponseOutputStream: ResponseWriter, Core.OutputStream {
    public typealias Output = Response
    public var output: OutputHandler?

    public init() {}

    public func write(_ response: Response) throws {
        try output?(response)
    }
}


public final class ResponderStream<R: Responder>: Core.Stream {
    public typealias Input = Request
    public typealias Output = Response

    let responder: R
    public var output: OutputHandler?

    public init(_ responder: R) {
        self.responder = responder
    }

    public func input(_ input: Request) throws {
        let writer = ResponseOutputStream()
        writer.output = output
        try responder.respond(to: input, using: writer)
    }
}

