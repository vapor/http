import Async
import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser: TranslatingStream where Output: HTTPMessage {}
