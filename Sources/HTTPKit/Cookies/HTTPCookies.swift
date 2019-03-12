/// A collection of `HTTPCookie`s.
public struct HTTPCookies: ExpressibleByDictionaryLiteral {
    /// Internal storage.
    private var cookies: [String: HTTPCookieValue]

    /// Creates an empty `HTTPCookies`
    public init() {
        self.cookies = [:]
    }

    // MARK: Parse

    /// Parses a `Request` cookie
    public static func parse(cookieHeader: String) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]

        // cookies are sent separated by semicolons
        let tokens = cookieHeader.components(separatedBy: ";")

        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = HTTPCookieValue.parse(token) else {
                return nil
            }

            cookies[name] = value
        }

        return cookies
    }

    /// Parses a `Response` cookie
    public static func parse(setCookieHeaders: [String]) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]

        for token in setCookieHeaders {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = HTTPCookieValue.parse(token) else {
                return nil
            }

            cookies[name] = value
        }

        return cookies
    }

    /// See `ExpressibleByDictionaryLiteral`.
    public init(dictionaryLiteral elements: (String, HTTPCookieValue)...) {
        var cookies: [String: HTTPCookieValue] = [:]
        for (name, value) in elements {
            cookies[name] = value
        }
        self.cookies = cookies
    }
    
    // MARK: Serialize

    /// Seriaizes the `Cookies` for a `Request`
    public func serialize(into request: inout HTTPRequest) {
        guard !cookies.isEmpty else {
            request.headers.remove(name: .cookie)
            return
        }

        let cookie: String = cookies.map { (name, value) in
            return "\(name)=\(value.string)"
        }.joined(separator: "; ")

        request.headers.replaceOrAdd(name: .cookie, value: cookie)
    }

    /// Seriaizes the `Cookies` for a `Response`
    public func serialize(into response: inout HTTPResponse)  {
        response.headers.remove(name: .setCookie)
        for (name, value) in cookies {
            response.headers.add(name: .setCookie, value: value.serialize(name: name))
        }
    }

    // MARK: Access
    
    /// All cookies.
    public var all: [String: HTTPCookieValue] {
        get { return cookies }
        set { cookies = newValue }
    }

    /// Access `HTTPCookies` by name
    public subscript(name: String) -> HTTPCookieValue? {
        get { return cookies[name] }
        set { cookies[name] = newValue }
    }
}
