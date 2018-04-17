/// A single cookie (key/value pair).
public struct HTTPCookie {
    /// Parses an individual `HTTPCookie` from a `String`.
    ///
    ///     let cookie = HTTPCookie.parse("sessionID=123; HTTPOnly")
    ///
    /// - parameters:
    ///     - data: `LosslessDataConvertible` to parse the cookie from.
    /// - returns: `HTTPCookie` or `nil` if the data is invalid.
    public static func parse(_ data: LosslessDataConvertible) -> HTTPCookie? {
        /// Parse `HeaderValue` or return nil.
        guard let header = HeaderValue.parse(data) else {
            return nil
        }

        /// Fetch name and value.
        var name: String
        var value: String

        let parts = header.value.split(separator: "=", maxSplits: 1)
        switch parts.count {
        case 2:
            name = String(parts[0]).trimmingCharacters(in: .whitespaces)
            value = String(parts[1]).trimmingCharacters(in: .whitespaces)
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

        return HTTPCookie(
            name: name,
            value: value,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            isSecure: secure,
            isHTTPOnly: httpOnly,
            sameSite: sameSite
        )
    }

    /// The cookie's key.
    public var name: String

    /// The cookie's value.
    public var value: String

    /// The `Cookie`'s expiration date
    public var expires: Date?

    /// The maximum `Cookie` age in seconds
    public var maxAge: Int?

    /// The affected domain at which the `Cookie` is active
    public var domain: String?

    /// The path at which the `Cookie` is active
    public var path: String?

    /// Limits the cookie to secure connections
    public var isSecure: Bool

    /// Does not expose the `Cookie` over non-HTTP channels
    public var isHTTPOnly: Bool

    /// A cookie which can only be sent in requests originating from the same origin as the target domain.
    ///
    /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
    public var sameSite: HTTPSameSitePolicy?

    /// Creates a new `HTTPCookie`.
    ///
    ///     let cookie = HTTPCookie(name: "sessionID", value: "123")
    ///
    /// - parameters:
    ///     - named: Key for this cookie.
    ///     - value: Value for this cookie.
    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = "/",
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: HTTPSameSitePolicy? = nil
    ) {
        self.name = name
        self.value = value
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }

    /// Seriaizes an `HTTPCookie` to a `String`.
    public func serialize() -> String {
        var serialized = "\(name)=\(value)"

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
    case strict = "Strict"
    case lax = "Lax"
}
