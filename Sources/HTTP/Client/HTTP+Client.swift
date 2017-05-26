import Transport
import Sockets

public enum ClientError: Swift.Error {
    case invalidRequestHost
    case invalidRequestScheme
    case invalidRequestPort
    case unableToConnect
    case userInfoNotAllowedOnHTTP
    case missingHost
}

public typealias TCPClient = BasicClient<TCPInternetSocket>

import TLS

public typealias TLSClient = BasicClient<TLS.InternetSocket>

public final class BasicClient<StreamType: ClientStream>: Client {
    // public let middleware: [Middleware]
    public let stream: StreamType

    public var scheme: String {
        return stream.scheme
    }

    public var hostname: String {
        return stream.hostname
    }

    public var port: Port {
        return stream.port
    }

    var buffer: Bytes
    
    public init(_ stream: StreamType) throws {
        self.stream = stream
        try stream.connect()
        buffer = Bytes(repeating: 0, count: 2048)
    }
    
    deinit {
        try? stream.close()
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        guard !stream.isClosed else {
            throw ClientError.unableToConnect
        }

        /// client MUST send a Host header field in all HTTP/1.1 request
        /// messages.  If the target URI includes an authority component, then a
        /// client MUST send a field-value for Host that is identical to that
        /// authority component, excluding any userinfo subcomponent and its "@"
        /// delimiter (Section 2.7.1).  If the authority component is missing or
        /// undefined for the target URI, then a client MUST send a Host header
        /// field with an empty field-value.
        request.headers["Host"] = stream.hostname
        request.headers["User-Agent"] = userAgent

        let serializer = RequestSerializer()
        while true {
            let serialized = try serializer.serialize(request, into: &buffer)
            guard serialized > 0 else {
                break
            }
            let written = try stream.write(max: serialized, from: buffer)
            guard written == serialized else {
                // FIXME: better error
                throw StreamError.closed
            }
        }
        
        switch request.body {
        case .chunked(let closure):
            let chunk = ChunkStream(stream)
            try closure(chunk)
        case .data(let bytes):
            _ = try stream.write(bytes)
        }

        let parser = ResponseParser()
        
        var response: Response?
        while response == nil {
            let read = try stream.read(max: buffer.count, into: &buffer)
            guard read > 0 else {
                break
            }
            response = try parser.parse(max: read, from: buffer)
        }
        
        guard let res = response else {
            throw StreamError.closed
        }

        // set the stream for peer information
        res.stream = stream
        
        return res
    }
}

let VERSION = "2"
public var userAgent = "App (Swift) VaporEngine/\(VERSION)"


extension Client {
    internal func assertValid(_ request: Request) throws {
        guard request.uri.userInfo == nil else {
            /// Userinfo (i.e., username and password) are now disallowed in HTTP and
            /// HTTPS URIs, because of security issues related to their transmission
            /// on the wire.  (Section 2.7.1)
            throw ClientError.userInfoNotAllowedOnHTTP
        }
    }
}
