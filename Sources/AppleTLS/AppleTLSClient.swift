import Async
import Security
import TCP
import TLS

/// A TLS client implemented by Apple security module.
public struct AppleTLSClient: TLSClient {
    /// The TLS socket.
    public let socket: AppleTLSSocket

    /// Underlying TCP client.
    private let tcp: TCPClient

    /// Create a new `AppleTLSClient`
    public init(tcp: TCPClient, using settings: TLSClientSettings) throws {
        let socket = try AppleTLSSocket(tcp: tcp.socket, protocolSide: .clientSide)

        if let clientCertificate = settings.clientCertificate {
            try socket.context.setCertificate(to: clientCertificate)
        }

        if let peerDomainName = settings.peerDomainName {
            try socket.context.setDomainName(to: peerDomainName)
        }

        self.tcp = tcp
        self.socket = socket
    }
    
    /// Create a new `AppleTLSClient`
    public init(tcp: TCPClient, using settings: TLSServerSettings) throws {
        let socket = try AppleTLSSocket(tcp: tcp.socket, protocolSide: .clientSide)
        
        try socket.context.setCertificate(to: settings.privateKey)
        
        try socket.context.setDomainName(to: settings.hostname)
        
        self.tcp = tcp
        self.socket = socket
    }

    /// See TLSClient.connect
    public func connect(hostname: String, port: UInt16) throws {
        try tcp.connect(hostname: hostname, port: port)
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.close()
    }
}
