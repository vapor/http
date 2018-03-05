import Foundation

/// An HTTP request from a client to a server.
public struct HTTPRequest: HTTPMessage {
    /// The HTTP method for this request.
    public var method: HTTPMethod

    /// The URI used on this request.
    public var url: URL {
        get {
            print("Convenience URL access.")
            return URL(string: urlString) ?? .root
        }
        set {
            print("Convenience URL set.")
            urlString = url.absoluteString
        }
    }

    public var urlString: String

    /// The version for this HTTP request.
    public var version: HTTPVersion

    /// The header fields for this HTTP request.
    public var headers: HTTPHeaders

    /// The http body.
    /// Updating this property will also update the associated transport headers.
    public var body: HTTPBody {
        didSet {
            updateTransportHeaders()
        }
    }

    /// Creates a new HTTP Request.
    public init(
        method: HTTPMethod = .GET,
        url: URL = .root,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: HTTPBody = .init()
    ) {
        self.method = method
        self.urlString = url.absoluteString
        self.version = version
        self.headers = headers
        self.body = body
        updateTransportHeaders()
    }

    /// Creates a new HTTPRequest without sanitizing headers.
    internal init(
        method: HTTPMethod,
        urlString: String,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPHeaders,
        body: HTTPBody
    ) {
        self.method = method
        self.urlString = urlString
        self.version = version
        self.headers = headers
        self.body = body
    }
}

extension URL {
    public static var root: URL {
        return _defaultURL
    }
}
private let _defaultURL = URL(string: "/")!

extension HTTPRequest {
    /// See `CustomStringConvertible.description
    public var description: String {
        var desc: [String] = []
        desc.append("\(method) \(url) HTTP/\(version.major).\(version.minor)")
        desc.append(headers.debugDescription)
        desc.append(body.description)
        return desc.joined(separator: "\n")
    }
}
