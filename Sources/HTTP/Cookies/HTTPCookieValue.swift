/// A single cookie (key/value pair).
public struct HTTPCookieValue: ExpressibleByStringLiteral {
    // MARK: Static

    /// An expired `HTTPCookieValue`.
    public static let expired: HTTPCookieValue = .init(string: "", expires: Date(timeIntervalSince1970: 0))

    /// Parses an individual `HTTPCookie` from a `String`.
    ///
    ///     let cookie = HTTPCookie.parse("sessionID=123; HTTPOnly")
    ///
    /// - parameters:
    ///     - data: `LosslessDataConvertible` to parse the cookie from.
    /// - returns: `HTTPCookie` or `nil` if the data is invalid.
    public static func parse(_ data: LosslessDataConvertible) -> (String, HTTPCookieValue)? {
        /// Parse `HeaderValue` or return nil.
        guard let header = HeaderValue.parse(data) else {
            return nil
        }

        /// Fetch name and value.
        var name: String
        var string: String

        let parts = header.value.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        switch parts.count {
        case 2:
            name = String(parts[0]).trimmingCharacters(in: .whitespaces)
            string = String(parts[1]).trimmingCharacters(in: .whitespaces)
        default: return nil
        }

        /// Fetch params.
        var expires: Date?
        var maxAge: Int?
        var domain: String?
        var path: String?
        var secure = false
        var httpOnly = false
        var sameSite: HTTPSameSitePolicy?

        for (key, val) in header.parameters {
            switch key {
            case "domain": domain = val
            case "path": path = val
            case "expires": expires = Date(rfc1123: val)
            case "httponly": httpOnly = true
            case "secure": secure = true
            case "max-age": maxAge = Int(val) ?? 0
            case "samesite": sameSite = HTTPSameSitePolicy(rawValue: val)
            default: break
            }
        }

        let value = HTTPCookieValue(
            string: string,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            isSecure: secure,
            isHTTPOnly: httpOnly,
            sameSite: sameSite
        )
        return (name, value)
    }

    // MARK: Properties

    /// The cookie's value.
    public var string: String

    /// The cookie's expiration date
    public var expires: Date?

    /// The maximum cookie age in seconds.
    public var maxAge: Int?

    /// The affected domain at which the cookie is active.
    public var domain: String?

    /// The path at which the cookie is active.
    public var path: String?

    /// Limits the cookie to secure connections.
    public var isSecure: Bool

    /// Does not expose the cookie over non-HTTP channels.
    public var isHTTPOnly: Bool

    /// A cookie which can only be sent in requests originating from the same origin as the target domain.
    ///
    /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
    public var sameSite: HTTPSameSitePolicy?

    // MARK: Init

    /// Creates a new `HTTPCookieValue`.
    ///
    ///     let cookie = HTTPCookieValue(string: "123")
    ///
    /// - parameters:
    ///     - value: Value for this cookie.
    ///     - expires: The cookie's expiration date. Defaults to `nil`.
    ///     - maxAge: The maximum cookie age in seconds. Defaults to `nil`.
    ///     - domain: The affected domain at which the cookie is active. Defaults to `nil`.
    ///     - path: The path at which the cookie is active. Defaults to `"/"`.
    ///     - isSecure: Limits the cookie to secure connections. Defaults to `false`.
    ///     - isHTTPOnly: Does not expose the cookie over non-HTTP channels. Defaults to `false`.
    ///     - sameSite: See `HTTPSameSitePolicy`. Defaults to `nil`.
    public init(
        string: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = "/",
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: HTTPSameSitePolicy? = nil
    ) {
        self.string = string
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }

    /// See `ExpressibleByStringLiteral`.
    public init(stringLiteral value: String) {
        self.init(string: value)
    }

    // MARK: Methods

    /// Seriaizes an `HTTPCookie` to a `String`.
    public func serialize(name: String) -> String {
        var serialized = "\(name)=\(string)"

        if let expires = self.expires {
            serialized += "; Expires=\(expires.rfc1123)"
        }

        if let maxAge = self.maxAge {
            serialized += "; Max-Age=\(maxAge)"
        }

        if let domain = self.domain {
            serialized += "; Domain=\(domain)"
        }

        if let path = self.path {
            serialized += "; Path=\(path)"
        }

        if isSecure {
            serialized += "; Secure"
        }

        if isHTTPOnly {
            serialized += "; HttpOnly"
        }

        if let sameSite = self.sameSite {
            serialized += "; SameSite"
            switch sameSite {
            case .lax:
                serialized += "=Lax"
            case .strict:
                serialized += "=Strict"
            }
        }

        return serialized
    }
}
/// A cookie which can only be sent in requests originating from the same origin as the target domain.
///
/// This restriction mitigates attacks such as cross-site request forgery (XSRF).
public enum HTTPSameSitePolicy: String {
    /// Strict mode.
    case strict = "Strict"
    /// Relaxed mode.
    case lax = "Lax"
}
