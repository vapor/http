/// A `Cookie` Array
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/cookies/#multiple-cookies)
public struct HTTPCookies {
    /// All `Cookie`s contained
    public var cookies: [HTTPCookie]

    /// Creates an empty `Cookies`
    public init() {
        self.cookies = []
    }

    /// Creates a `Cookies` from the contents of a `Cookie` Sequence
    public init<C>(cookies: C) where C.Iterator.Element == HTTPCookie, C: Sequence {
        self.cookies = Array(cookies)
    }

    /// Access a `Cookie` by name
    public subscript(name: String) -> HTTPCookieValue? {
        get {
            guard let index = cookies.index(where: { $0.name == name }) else {
                return nil
            }

            return cookies[index].value
        }
        set {
            guard let index = cookies.index(where: { $0.name == name }) else {
                if let newValue = newValue {
                    cookies.append(HTTPCookie(named: name, value: newValue))
                }

                return
            }

            if let newValue = newValue {
                cookies[index].value = newValue
            } else {
                cookies.remove(at: index)
            }
        }
    }
}

extension HTTPCookies: ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    /// Creates a `Cookies` from an array of cookies
    public init(arrayLiteral elements: HTTPCookie...) {
        self.cookies = elements
    }

    /// Creates a `Cookies` from an array of names and cookie values
    public init(dictionaryLiteral elements: (String, HTTPCookieValue)...) {
        self.cookies = elements.map { name, value in
            return HTTPCookie(named: name, value: value)
        }
    }

}

extension HTTPCookies: Sequence {
    /// Iterates over all `Cookie`s
    public func makeIterator() -> IndexingIterator<[HTTPCookie]> {
        return cookies.makeIterator()
    }
}

/// MARK: Message

extension HTTPRequest {
    /// Sets and extracts `Cookies` from the `Request`
    public var cookies: HTTPCookies {
        get {
            guard let cookie = headers[.cookie].first else {
                return []
            }
            return HTTPCookies(cookieHeader: cookie) ?? []
        }
        set(cookies) {
            cookies.serialize(into: &self)
        }
    }
}

extension HTTPResponse {
    /// Sets and extracts `Cookies` from the `Response`
    public var cookies: HTTPCookies {
        get {
            return HTTPCookies(setCookieHeaders: headers[.setCookie]) ?? []
        }
        set(cookies) {
            cookies.serialize(into: &self)
        }
    }
}


/// MARK: Parse

extension HTTPCookies {
    /// Parses a `Request` cookie
    public init?(cookieHeader: String) {
        var cookies: HTTPCookies = []

        // cookies are sent separated by semicolons
        let tokens = cookieHeader.components(separatedBy: ";")

        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = HTTPCookie.parse(from: token) else {
                return nil
            }

            cookies[cookie.name] = cookie.value
        }

        self = cookies
    }

    /// Parses a `Response` cookie
    public init?(setCookieHeaders: [String]) {
        var cookies: HTTPCookies = []

        for token in setCookieHeaders {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = HTTPCookie.parse(from: token) else {
                return nil
            }

            cookies[cookie.name] = cookie.value
        }

        self = cookies
    }
}

/// MARK: Serialization

extension HTTPCookies {
    /// Seriaizes the `Cookies` for a `Request`
    public func serialize(into request: inout HTTPRequest) {
        guard !cookies.isEmpty else {
            request.headers.remove(name: .cookie)
            return
        }

        let cookie: String = map { cookie in
            return "\(cookie.name)=\(cookie.value.string)"
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
}

extension HTTPCookie {
    /// Seriaizes an individual `Cookie`
    public func serialize() -> String {
        var serialized = "\(name)=\(value.string)"

        if let expires = value.expires {
            serialized += "; Expires=\(expires.rfc1123)"
        }

        if let maxAge = value.maxAge {
            serialized += "; Max-Age=\(maxAge)"
        }

        if let domain = value.domain {
            serialized += "; Domain=\(domain)"
        }

        if let path = value.path {
            serialized += "; Path=\(path)"
        }

        if value.secure {
            serialized += "; Secure"
        }

        if value.httpOnly {
            serialized += "; HttpOnly"
        }

        if let sameSite = value.sameSite {
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
