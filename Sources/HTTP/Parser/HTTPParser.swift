import Async
import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser : Async.Stream, ConnectionContext where Output == Message, Input == ByteBuffer {
    /// The message the parser handles.
    associatedtype Message: HTTPMessage

    /// The parsed message.
    /// Becomes non-nil after completely parsed.
    /// Seeting this property to `nil` resets the parser.
    var message: Message? { get set }
    
    /// Indicates that the `message`'s body has completely been serialized
    /// and a new message can be parsed
    var messageBodyCompleted: Bool { get set}

    /// Parses data from the supplied buffer.
    /// Returns the number of bytes parsed.
    /// If the number of bytes parsed is 0, the parser is done.
    func parse(from buffer: ByteBuffer) throws -> Int
}
