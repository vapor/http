/// An HTTP request from a client to a server.
///
///     let httpReq = HTTPRequest(method: .GET, url: "/hello")
///
/// See `HTTPClient` and `HTTPServer`.
public struct HTTPRequest: HTTPMessage {
    /// Internal storage is an NIO `HTTPRequestHead`
    internal var head: HTTPRequestHead

    // MARK: Properties

    /// The HTTP method for this request.
    ///
    ///     httpReq.method = .GET
    ///
    public var method: HTTPMethod {
        get { return head.method }
        set { head.method = newValue }
    }

    /// The URL used on this request.
    public var url: URL {
        get { return URL(string: urlString) ?? .root }
        set { urlString = newValue.absoluteString }
    }

    /// The unparsed URL string. This is usually set through the `url` property.
    ///
    ///     httpReq.urlString = "/welcome"
    ///
    public var urlString: String {
        get { return head.uri }
        set { head.uri = newValue }
    }

    /// The version for this HTTP request.
    public var version: HTTPVersion {
        get { return head.version }
        set { head.version = newValue }
    }

    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders {
        get { return head.headers }
        set { head.headers = newValue }
    }

    /// The `HTTPBody`. Updating this property will also update the associated transport headers.
    ///
    ///     httpReq.body = HTTPBody(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `HTTPBody`.
    public var body: HTTPBody {
        didSet { updateTransportHeaders() }
    }

    /// If set, reference to the NIO `Channel` this request came from.
    public var channel: Channel?

    /// Get and set `HTTPCookies` for this `HTTPRequest`
    /// This accesses the `"Cookie"` header.
    public var cookies: HTTPCookies {
        get { return headers.firstValue(name: .cookie).flatMap(HTTPCookies.parse) ?? [:] }
        set { newValue.serialize(into: &self) }
    }

    /// See `CustomStringConvertible`
    public var description: String {
        var desc: [String] = []
        desc.append("\(method) \(url) HTTP/\(version.major).\(version.minor)")
        desc.append(headers.debugDescription)
        desc.append(body.description)
        return desc.joined(separator: "\n")
    }

    // MARK: Init

    /// Creates a new `HTTPRequest`.
    ///
    ///     let httpReq = HTTPRequest(method: .GET, url: "/hello")
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to use. This defaults to `HTTPMethod.GET`.
    ///     - url: A `URLRepresentable` item that represents the request's URL.
    ///            This defaults to `"/"`.
    ///     - version: `HTTPVersion` of this request, should usually be (and defaults to) 1.1.
    ///     - headers: `HTTPHeaders` to include with this request.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `HTTPBody` for this request, defaults to an empty body.
    ///             See `LosslessHTTPBodyRepresentable` for more information.
    public init(
        method: HTTPMethod = .GET,
        url: URLRepresentable = URL.root,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: LosslessHTTPBodyRepresentable = HTTPBody()
    ) {
        var head = HTTPRequestHead(version: version, method: method, uri: url.convertToURL()?.absoluteString ?? "/")
        head.headers = headers
        self.init(
            head: head,
            body: body.convertToHTTPBody(),
            channel: nil
        )
        updateTransportHeaders()
    }

    /// Internal init that creates a new `HTTPRequest` without sanitizing headers.
    internal init(head: HTTPRequestHead, body: HTTPBody, channel: Channel?) {
        self.head = head
        self.body = body
        self.channel = channel
    }
}
