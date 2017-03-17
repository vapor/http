import Transport

public enum MessageError: Error {
    case invalidStartLine
}

/// Represents the information we have about the remote
/// peer of this message.
/// The peer (remote/client) address is important
/// for availability (block bad clients by their IP)
/// or even security.
/// We can always get the remote IP of the connection
/// from the Stream. However, when clients go through
/// a proxy or a load balancer, we'd like to get the
/// original client's IP. Most proxy servers and load
/// balancers communicate the information about the
/// original client in certain headers.
/// See https://en.wikipedia.org/wiki/X-Forwarded-For
public struct PeerAddress {

    /// A newer version, sent by other proxies, only use
    /// if you can trust the proxy (easily spoofed).
    public let forwarded: String?

    /// Sent by certain proxies, only use if you can
    /// trust the proxy (easily spoofed).
    public let xForwardedFor: String?
    
    /// The stream (socket) remote address, pulled out
    /// of the system. More difficult (but possible) to
    /// spoof.
    public let stream: String
    
    public init(forwarded: String? = nil, xForwardedFor: String? = nil, stream: String) {
        self.forwarded = forwarded
        self.xForwardedFor = xForwardedFor
        self.stream = stream
    }
    
    /// Tries to parse the headers first, falls back to the
    /// socket address. If proxies are used, please ensure
    /// you can trust them.
    public func address() -> String {
        return forwarded ?? xForwardedFor ?? stream
    }
}

public class Message {
    public let startLine: String
    public var headers: [HeaderKey: String]

    // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
    // must NOT be exposed public because changing body will break behavior most of time
    public var body: Body

    public var storage: [String: Any] = [:]
    
    /// The address of the remote peer of this message.
    public var peerAddress: PeerAddress?

    public convenience required init(
        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
        headers: [HeaderKey: String],
        body: Body,
        peerAddress: PeerAddress? = nil
    ) throws {
        var startLine = startLineComponents.0.makeString()
        startLine += " "
        startLine += startLineComponents.1.makeString()
        startLine += " "
        startLine += startLineComponents.2.makeString()

        self.init(startLine: startLine, headers: headers, body: body, peerAddress: peerAddress)
    }

    public init(startLine: String, headers: [HeaderKey: String], body: Body, peerAddress: PeerAddress?) {
        self.startLine = startLine
        self.headers = headers
        self.body = body
        self.peerAddress = peerAddress
    }
}

extension Message: TransferMessage {}

extension Message {
    public var contentType: String? {
        return headers["Content-Type"]
    }
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        return !value.contains("close")
    }
}
