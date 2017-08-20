import Core
import Dispatch

public protocol Responder {
    func respond(to req: Request) throws -> Future<ResponseRepresentable>
}

extension Responder {
    public func makeStream(on queue: DispatchQueue) -> ResponderStream {
        return ResponderStream(
            responder: self,
            queue: queue
        )
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
    let queue: DispatchQueue

    public init(responder: Responder, queue: DispatchQueue) {
        self.responder = responder
        self.queue = queue
    }

    public func inputStream(_ input: Request) {
        let writer = ResponseOutputStream()
        writer.outputStream = outputStream
        do {
            try responder.respond(to: input).then(asynchronously: queue) { res in
                do {
                    try writer.write(res)
                } catch {
                    self.errorStream?(error)
                }
            }
        } catch {
            errorStream?(error)
        }
    }
}

