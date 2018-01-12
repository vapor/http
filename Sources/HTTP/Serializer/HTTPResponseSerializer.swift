import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class HTTPResponseSerializer: _HTTPSerializer {
    /// See HTTPSerializer.Message
    public typealias Message = HTTPResponse

    /// Serialized message
    var firstLine: [UInt8]?
    
    /// Headers
    var headersData: Data?

    /// Body data
    var staticBodyData: HTTPBody?

    /// The current offset
    var offset: Int
    
    /// The current serialization taking place
    var state = HTTPSerializerState.noMessage {
        didSet {
            switch self.state {
            case .headers:
                self.firstLine = nil
            case .noMessage:
                self.headersData = nil
                self.firstLine = nil
                self.staticBodyData = nil
            default: break
            }
        }
    }

    /// Create a new HTTPResponseSerializer
    public init() {
        offset = 0
    }
    
    /// Set up the variables for Message serialization
    public func setMessage(to message: Message) {
        offset = 0
        
        self.state = .firstLine
        var headers = message.headers
        
        headers[.contentLength] = nil
        
        if case .chunkedOutputStream = message.body.storage {
            headers[.transferEncoding] = "chunked"
            self.headersData = headers.clean()
        } else {
            headers.appendValue(message.body.count.description, forName: .contentLength)
            self.headersData = headers.clean()
        }
        
        self.firstLine = message.firstLine

        switch message.body.storage {
        case .data(_):
            self.staticBodyData = message.body
        case .dispatchData(_):
            self.staticBodyData = message.body
        case .staticString(_):
            self.staticBodyData = message.body
        case .string(_):
            self.staticBodyData = message.body
        case .chunkedOutputStream: break
        case .none: break
        case .binaryOutputStream(_): break
        }
    }
}

fileprivate extension HTTPResponse {
    var firstLine: [UInt8] {
        // First line
        var http1Line = http1Prefix
        http1Line.reserveCapacity(128)
        
        http1Line.append(contentsOf: self.status.code.description.utf8)
        http1Line.append(.space)
        http1Line.append(contentsOf: self.status.messageBytes)
        http1Line.append(contentsOf: crlf)
        return http1Line
    }
}

private let http1Prefix = [UInt8]("HTTP/1.1 ".utf8)
private let crlf = [UInt8]("\r\n".utf8)
private let headerKeyValueSeparator = [UInt8](": ".utf8)
