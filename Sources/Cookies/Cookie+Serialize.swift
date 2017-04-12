import Core

extension Cookie {
    /**
        Serialized the cookie into a String.
    */
    public func serialize() -> String {
        var serialized = "\(name)=\(value)"

        if let expires = expires {
            serialized += "; Expires=\(expires.rfc1123)"
        }

        if let maxAge = maxAge {
            serialized += "; Max-Age=\(maxAge)"
        }

        if let domain = domain {
            serialized += "; Domain=\(domain)"
        }

        if let path = path {
            serialized += "; Path=\(path)"
        }

        if secure {
            serialized += "; Secure"
        }

        if httpOnly {
            serialized += "; HttpOnly"
        }
        
        if let sameSite = sameSite {
            serialized += "; SameSite"
            switch sameSite {
            case .lax:
                serialized += "=Lax"
            default:
                serialized += "=Strict"
            }
        }
        
        return serialized
    }
}
