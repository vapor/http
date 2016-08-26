import Core
import SocksCore

extension TCPInternetSocket: Stream {
    public var peerAddress: String {
        let address = self.address
        guard let addressFamily = try? address.addressFamily() else {
            return "unknown address family"
        }
        switch addressFamily {
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

import TLS

public final class TCPClientStream: TCPProgramStream, ClientStream  {
    public func connect() throws -> Stream {
        try stream.connect()
        switch securityLayer {
        case .none:
            return stream
        case .tls:
            let secure = try stream.makeSecret(mode: .client)
            try secure.stream.connect(servername: host)
            return secure
        }
    }
}

public final class TCPServerStream: TCPProgramStream, ServerStream {
    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        try super.init(host: host, port: port, securityLayer: securityLayer)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        let next = try stream.accept()
        switch securityLayer {
        case .none:
            return next
        case .tls:
            let secure = try next.makeSecret(mode: .server)
            try secure.stream.accept()
            return secure
        }
    }
}

import TLS
import SocksCore
import libc

public final class TLSSocket<Socket: SocksCore.TCPInternetSocket> {
    public let stream: TLS.Stream
    public let socket: Socket

    public init(stream: TLS.Stream, socket: Socket) {
        self.stream = stream
        self.socket = socket
    }

    public convenience init(
        mode: TLS.Mode,
        socket: Socket,
        certificates: TLS.Certificates = .none
    ) throws {
        let stream = try TLS.Stream(
            mode: mode,
            socket: socket.descriptor,
            certificates: certificates
        )
        self.init(stream: stream, socket: socket)
    }
}

/**
    Conform TLS Stream + Underlying socket
    to a TLS Socket.
*/
extension TLSSocket: Stream {
    public func close() throws {
        try stream.close()
        try socket.close()
    }

    public var closed: Bool {
        return socket.closed
    }

    public var peerAddress: String {
        return socket.peerAddress
    }

    public func setTimeout(_ timeout: Double) throws {
        try socket.setTimeout(timeout)
    }

    public func send(_ bytes: Bytes) throws {
        try stream.send(bytes)
    }

    public func receive(max: Int) throws -> Bytes {
        return try stream.receive(max: max)
    }

    public func flush() throws {
        try socket.flush()
    }
}

extension TCPInternetSocket {
    /**
        Creates a new SSL Context and Secure Socket.
        - parameter mode: Client or Server
        - parameter certificates: SSL Certificates for the Server, use .none for Client
     */
    public func makeSecret(
        mode: TLS.Mode = .client,
        certificates: TLS.Certificates = .none
    ) throws -> TLSSocket<TCPInternetSocket> {
        return try TLSSocket(
            mode: mode,
            socket: self,
            certificates: certificates
        )
    }
}
