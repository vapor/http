import Core

public protocol Responder {
    func respond(to req: Request, using writer: ResponseWriter) throws
}

extension Responder {
    public func makeStream() -> ResponderStream {
        return ResponderStream(self)
    }
}

// MARK: Writer

public protocol ResponseWriter {
    func write(_ response: Response)
}

extension ResponseWriter {
    public func write(_ response: ResponseRepresentable) throws {
        return try write(response.makeResponse())
    }
}

// MARK: Stream

public final class ResponseOutputStream: ResponseWriter, Core.OutputStream {
    public typealias Output = Response
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?

    public init() {}

    public func write(_ response: Response) {
        outputStream?(response)
    }
}


public final class ResponderStream: Core.Stream {
    public typealias Input = Request
    public typealias Output = Response
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    let responder: Responder

    public init(_ responder: Responder) {
        self.responder = responder
    }

    public func inputStream(_ input: Request) {
        let writer = ResponseOutputStream()
        writer.outputStream = outputStream
        do {
            try responder.respond(to: input, using: writer)
        } catch {
            errorStream?(error)
        }
    }
}

