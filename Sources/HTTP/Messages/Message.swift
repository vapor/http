import Transport
import URI

public protocol Message: class {
    var version: Version { get set }
    var headers: [HeaderKey: String] { get set }
    var body: Body { get set }
    var peerAddress: PeerAddress? { get set }
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
