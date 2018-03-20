import Foundation

public struct HTTPCookieValue {
    /// The `Cookie`'s associated value
    public var string: String

    /// The `Cookie`'s expiration date
    public var expires: Date?

    /// The maximum `Cookie` age in seconds
    public var maxAge: Int?

    /// The affected domain at which the `Cookie` is active
    public var domain: String?

    /// The path at which the `Cookie` is active
    public var path: String?

    /// Limits the `Cookie` to secure connections
    public var secure: Bool = false

    /// Does not expose the `Cookie` over non-HTTP channels
    public var httpOnly: Bool = false

    /// A cookie which can only be sent in requests originating from the same origin as the target domain.
    ///
    /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
    public var sameSite: HTTPSameSitePolicy?

    /// Creates a new `Cookie` value
    public init(
        string: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = "/",
        secure: Bool = false,
        httpOnly: Bool = false,
        sameSite: HTTPSameSitePolicy? = nil
    ) {
        self.string = string
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.secure = secure
        self.httpOnly = httpOnly
        self.sameSite = sameSite
    }
}


/// A cookie which can only be sent in requests originating from the same origin as the target domain.
///
/// This restriction mitigates attacks such as cross-site request forgery (XSRF).
public enum HTTPSameSitePolicy: String {
    case strict = "Strict"
    case lax = "Lax"
}

extension HTTPCookieValue: ExpressibleByStringLiteral {
    /// Creates a value-only (no attributes) value
    public init(stringLiteral value: String) {
        self.string = value
    }
}

/// Can be initialized by a CookieValue
public protocol HTTPCookieValueInitializable {
    /// Creates a new instance from a value
    init(from value: HTTPCookieValue) throws
}

/// Can be represented as a CookieValue
public protocol HTTPCookieValueRepresentable {
    /// Creates a new `Cookie.Value` from this instance
    func makeCookieValue() throws -> HTTPCookieValue
}

extension HTTPCookieValue: HTTPCookieValueInitializable, HTTPCookieValueRepresentable {
    /// Initializes itself to itself
    public init(from value: HTTPCookieValue) throws {
        self = value
    }

    /// Returns itself
    public func makeCookieValue() throws -> HTTPCookieValue {
        return self
    }
}

extension String: HTTPCookieValueRepresentable {
    public func makeCookieValue() throws -> HTTPCookieValue {
        return HTTPCookieValue(string: self)
    }
}
