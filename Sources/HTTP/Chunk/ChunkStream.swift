import Transport

/// Chunked transfer encoding is a data transfer mechanism in
/// version 1.1 of the Hypertext Transfer Protocol (HTTP) in which
/// data is sent in a series of "chunks".
///
/// the sender does not need to know
/// the length of the content before it starts transmitting a response
/// to the receiver. Senders can begin transmitting dynamically-generated
/// content before knowing the total size of that content.
///
/// https://en.wikipedia.org/wiki/Chunked_transfer_encoding
public class ChunkStream {
    public let raw: WriteableStream
    public var isClosed: Bool

    public init(_ stream: WriteableStream) {
        self.raw = stream
        isClosed = false
    }

    public func write(_ int: Int) throws {
        try write("\(int)")
    }

    public func write(_ string: String) throws {
        try write(string.makeBytes())
    }

    public func write(_ bytes: Bytes) throws {
        try write(bytes, timingOut: 0)
    }

    public func write(_ bytes: Bytes, timingOut deadline: Double) throws {
        var buffer = "\(bytes.count.hex)\r\n".makeBytes()
        buffer += bytes
        buffer += "\r\n".makeBytes()
        _ = try raw.write(buffer)
    }

    public func close() throws {
        _ = try raw.write("0\r\n\r\n") // stream should close by client
        isClosed = true
    }
}
