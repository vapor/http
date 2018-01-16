import Async
import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser: ByteParser where Output: HTTPMessage {}
