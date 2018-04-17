/// A collection of `HTTPCookie`s.
public struct HTTPCookies: ExpressibleByArrayLiteral, Sequence {
    /// Internal storage.
    private var cookies: [HTTPCookie]

    /// Creates an empty `HTTPCookies`
    public init() {
        self.cookies = []
    }

    // MARK: Parse

    /// Parses a `Request` cookie
    public static func parse(cookieHeader: String) -> HTTPCookies? {
        var cookies: HTTPCookies = []

        // cookies are sent separated by semicolons
        let tokens = cookieHeader.components(separatedBy: ";")

        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = HTTPCookie.parse(token) else {
                return nil
            }

            cookies.add(cookie)
        }

        return cookies
    }

    /// Parses a `Response` cookie
    public static func parse(setCookieHeaders: [String]) -> HTTPCookies? {
        var cookies: HTTPCookies = []

        for token in setCookieHeaders {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = HTTPCookie.parse(token) else {
                return nil
            }

            cookies.add(cookie)
        }

        return cookies
    }

    /// Creates a `Cookies` from the contents of a `Cookie` Sequence
    public init<C>(cookies: C) where C.Iterator.Element == HTTPCookie, C: Sequence {
        self.cookies = Array(cookies)
    }

    /// See `ExpressibleByArrayLiteral`.
    public init(arrayLiteral elements: HTTPCookie...) {
        self.cookies = elements
    }

    /// Access `HTTPCookies` by name
    public subscript(name: String) -> [HTTPCookie] {
        return cookies.filter { $0.name == name }
    }

    // MARK: Serialize

    /// Seriaizes the `Cookies` for a `Request`
    public func serialize(into request: inout HTTPRequest) {
        guard !cookies.isEmpty else {
            request.headers.remove(name: .cookie)
            return
        }

        let cookie: String = map { cookie in
            return cookie.serialize()
        }.joined(separator: "; ")

        request.headers.replaceOrAdd(name: .cookie, value: cookie)
    }

    /// Seriaizes the `Cookies` for a `Response`
    public func serialize(into response: inout HTTPResponse)  {
        guard !cookies.isEmpty else {
            response.headers.remove(name: .setCookie)
            return
        }

        for cookie in self {
            response.headers.add(name: .setCookie, value: cookie.serialize())
        }
    }

    // MARK: Access

    /// Fetches the first `HTTPCookie` with matching name.
    public func firstCookie(named name: String) -> HTTPCookie? {
        for cookie in cookies {
            if cookie.name == name {
                return cookie
            }
        }
        return nil
    }

    /// Adds a new `HTTPCookie`, removing all existing cookies with the same name
    /// if any exist.
    ///
    /// - parameters:
    ///     - cookie: New `HTTPCookie` to add.
    public mutating func replaceOrAdd(_ cookie: HTTPCookie) {
        remove(name: cookie.name)
        add(cookie)
    }

    /// Removes all `HTTPCookie`s with the supplied name.
    public mutating func remove(name: String) {
        cookies = cookies.filter { $0.name != name }
    }

    /// Adds a new `HTTPCookie`, even if one with the same name already exists.
    ///
    /// - parameters:
    ///     - cookie: New `HTTPCookie` to add.
    public mutating func add(_ cookie: HTTPCookie) {
        cookies.append(cookie)
    }

    /// See `Sequence`.
    public func makeIterator() -> IndexingIterator<[HTTPCookie]> {
        return cookies.makeIterator()
    }
}
