import Async
import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser: Async.Stream where Output: HTTPMessage {}
