import Core
import SocksCore

extension TCPInternetSocket: Stream {
    
    public var peerAddress: String {
        let address = self.address
        switch try! address.addressFamily() {
        case .inet:
            // IPv4: e.g. "10.0.0.141:63234"
            return "\(address.ipString()):\(address.port)"
        case .inet6:
            // IPv6: e.g. "[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443"
            return "[\(address.ipString())]:\(address.port)"
        case .unspecified:
            //input by user, system never resolves an address to .unspecified
            //ideally, we'd do a quick analysis of whether it's a hostname (treat as IPv4),
            //or IPv4 literal (treat as IPv4) or IPv6 literal (treat as IPv6).
            //most common are the first two, for simplicity we'll treat is at IPv4 always for now.
            return "\(address.ipString()):\(address.port)"
        }
    }

    public func setTimeout(_ timeout: Double) throws {
        sendingTimeout = timeval(seconds: timeout)
    }

    public func send(_ bytes: Bytes) throws {
        do {
            try send(data: bytes)
        } catch {
            throw StreamError.send("There was a problem while sending data.", error)
        }
    }

    public func flush() throws {
        // flushing is unnecessary, send immediately sends
    }

    public func receive(max: Int) throws -> Bytes {
        let bytes: Bytes
        do {
            bytes = try recv(maxBytes: max)
        } catch {
            throw StreamError.receive("There was a problem while receiving data.", error)
        }
        return bytes
    }
}

public class TCPProgramStream: ProgramStream {
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public let stream: TCPInternetSocket

    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer

        let address = InternetAddress(hostname: host, port: Port(port))
        stream = try TCPInternetSocket(address: address)
    }
}

public final class TCPClientStream: TCPProgramStream, ClientStream  {
    public func connect() throws -> Stream {
        if securityLayer == .tls {
            #if !os(Linux)
                print("Making TLS call over Foundation APIs. This will break on Linux. Visit https://github.com/qutheory/vapor-tls")
                let foundation = try FoundationStream(host: host, port: port, securityLayer: securityLayer)
                return try foundation.connect()
            #else
                throw ProgramStreamError.unsupportedSecurityLayer
            #endif
        }
        try stream.connect()
        return stream
    }
}

public final class TCPServerStream: TCPProgramStream, ServerStream {
    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        try super.init(host: host, port: port, securityLayer: securityLayer)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        return try stream.accept()
    }
}
