extension Stream {
    public var sender: Sender {
        return Sender(self)
    }
}

/**
    Wraps a Vapor.Stream as a C7.SendingStream.
*/
public class Sender: SendingStream {
    public let stream: Stream

    public init(_ stream: Stream) {
        self.stream = stream
    }

    public var closed: Bool {
        return stream.closed
    }

    public func close() throws {
        try stream.close()
    }

    public func send(_ data: Data, timingOut deadline: Double) throws {
        try stream.setTimeout(deadline)
        try stream.send(data.bytes)
    }

    public func flush(timingOut deadline: Double) throws {
        try stream.setTimeout(deadline)
        try stream.flush()
    }
    
}
