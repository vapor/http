import Async
import Bits
import Foundation

/// HTTP message parser.
public protocol HTTPParser: ByteParser where Partial == CParseResults, Output: HTTPMessage {}
