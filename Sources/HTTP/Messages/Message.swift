import Transport
import URI

public protocol Message: class {
    var version: Version { get set }
    var headers: [HeaderKey: String] { get set }
    var body: Body { get set }
    var storage: [String: Any] { get set }
}

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

// MARK: Peer information

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

extension Message {
    /// The stream that was used to
    /// parse this message.
    public var stream: InternetStream? {
        get {
            return storage["stream"] as? InternetStream
        }
        set {
            storage["stream"] = newValue
        }
    }
    
    /// Tries to parse the headers first, falls back to the
    /// socket address. If proxies are used, please ensure
    /// you can trust them.
    public var peerHostname: String? {
        if let forwarded = headers["Forwarded"] {
            return Forwarded(forwarded)?.for
        } else {
            /// Sent by certain proxies, only use if you can
            /// trust the proxy (easily spoofed).
            return headers["X-Forwarded-For"]
                ?? stream?.hostname
        }
    }
    
    /// The scheme of this message's peer.
    public var peerScheme: String? {
        if let forwarded = headers["Forwarded"] {
            return Forwarded(forwarded)?.proto
        } else {
            return headers["X-Forwarded-Proto"]
                ?? headers["X-Scheme"]
                ?? stream?.scheme
        }
    }
    
    /// The port of this message's peer.
    public var peerPort: Port? {
        if let forwardedPort = headers["X-Forwarded-Port"] {
            return Port(forwardedPort)
        }
        return stream?.port
    }
}

/// Parses the `Forwarded` header.
public struct Forwarded {
    public var `for`: String?
    public var proto: String?
    public var by: String?
    
    /// Creates a new Forwaded header object from the header value.
    public init?(_ string: String) {
        let parts = string
            .components(separatedBy: ";")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines )})
            .map({ $0.components(separatedBy: "=") })
        
        for part in parts {
            guard part.count == 2 else {
                continue
            }
            switch part[0] {
            case "for":
                self.for = part[1]
            case "proto":
                self.proto = part[1]
            case "by":
                self.by = part[1]
            default:
                break
            }
        }
    }
}
