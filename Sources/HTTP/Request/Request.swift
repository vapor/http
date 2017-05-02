import Core
import URI

public final class Request: Message {
    public var method: Method
    public var uri: URI
    public var version: Version
    public var headers: [HeaderKey: String]
    public var body: Body
    public var storage: [String: Any]
    
    public init(
        method: Method,
        uri: URI,
        version: Version = Version(major: 1, minor: 1),
        headers: [HeaderKey: String] = [:],
        body: Body = .data([])
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
        self.storage = [:]
    }
}

extension Request {
    public convenience init(
        method: Method,
        uri: String,
        version: Version = Version(major: 1, minor: 1),
        headers: [HeaderKey: String] = [:],
        body: Body = .data([])
    ) {
        let uri = URIParser.shared.parse(bytes: uri.makeBytes())
        self.init(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )
    }
}
