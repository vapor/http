import Foundation

/// A single Key-Value pair
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/cookies/#a-single-cookie)
public struct HTTPCookie {
    /// The cookie's `Key`/name
    public var name: String

    /// The cookie's `Value` contains the value and parameters
    public var value: HTTPCookieValue

    /// Creates a new Cookie
    public init(named name: String, value: HTTPCookieValue) {
        self.name = name
        self.value = value
    }
}

extension HTTPCookie {
    /// Parses an individual `Cookie`
    public static func parse(from string: String) -> HTTPCookie? {
        var name: String?
        var valueString: String?
        var expires: Date?
        var maxAge: Int?
        var domain: String?
        var path: String?
        var secure = false
        var httpOnly = false
        var sameSite: HTTPSameSitePolicy?

        // cookies are sent separated by semicolons
        let tokens = string.split(separator: ";")

        for token in tokens {
            let cookieTokens = token.split(separator: "=", maxSplits: 1)

            // cookies could be sent with space after
            // the semicolon so we should trim
            let key = String(cookieTokens[0]).trimmingCharacters(in: [" "])

            let val: String
            if cookieTokens.count == 2 {
                val = String(cookieTokens[1])
            } else {
                val = ""
            }

            switch key.lowercased() {
            case "domain":
                domain = val
            case "path":
                path = val
            case "expires":
                expires = Date(rfc1123: val)
            case "httponly":
                httpOnly = true
            case "secure":
                secure = true
            case "max-age":
                maxAge = Int(val) ?? 0
            case "samesite":
                if val.lowercased() == "lax" {
                    sameSite = .lax
                } else {
                    sameSite = .strict
                }
            default:
                name = key
                valueString = val
            }
        }

        guard let cookieName = name, let value = valueString else {
            return nil
        }

        let cookieValue = HTTPCookieValue(
            string: value,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            secure: secure,
            httpOnly: httpOnly,
            sameSite: sameSite
        )
        return .init(named: cookieName, value: cookieValue)
    }
}
