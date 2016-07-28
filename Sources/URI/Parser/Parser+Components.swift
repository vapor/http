import Core

extension URIParser {
    /**
        https://tools.ietf.org/html/rfc3986#section-3.1

        Scheme names consist of a sequence of characters beginning with a
        letter and followed by any combination of letters, digits, plus
        ("+"), period ("."), or hyphen ("-").  Although schemes are case-
        insensitive, the canonical form is lowercase and documents that
        specify schemes must do so with lowercase letters.  An implementation
        should accept uppercase letters as equivalent to lowercase in scheme
        names (e.g., allow "HTTP" as well as "http") for the sake of
        robustness but should only produce lowercase scheme names for
        consistency.

        scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    */
    internal func parseScheme() throws -> [Byte] {
        // MUST begin with letter
        guard try next(matches: { $0.isLetter } ) else { return [] }

        let scheme = try collect(until: .colon, .forwardSlash)
        let colon = try checkLeadingBuffer(matches: .colon)
        guard colon else { return scheme }
        // if matches ':', then we have a scheme
        // clear ':' delimitter and continue we don't use this for further parsing
        try discardNext(1)
        return scheme
    }

    /**
        https://tools.ietf.org/html/rfc3986#section-3.2

        The authority component is preceded by a double slash ("//") and is
        terminated by the next slash ("/"), question mark ("?"), or number
        sign ("#") character, or by the end of the URI.

        authority   = [ userinfo "@" ] host [ ":" port ]
    */
    internal func parseAuthority() throws -> [Byte]? {
        if let existingHost = existingHost { return existingHost.array }
        guard try checkLeadingBuffer(matches: .forwardSlash, .forwardSlash) else { return nil }
        try discardNext(2) // discard '//'
        return try collect(until: .forwardSlash, .questionMark, .numberSign)
    }

    /**
        https://tools.ietf.org/html/rfc3986#section-3.3

        The path is terminated
        by the first question mark ("?") or number sign ("#") character, or
        by the end of the URI.

        If a URI contains an authority component, then the path component
        must either be empty or begin with a slash ("/") character.
    */
    internal func parsePath() throws -> [Byte] {
        return try collect(until: .questionMark, .numberSign)
    }

    /**
        https://tools.ietf.org/html/rfc3986#section-3.4

        The query component is indicated by the first question
        mark ("?") character and terminated by a number sign ("#") character
        or by the end of the URI.
    */
    internal func parseQuery() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .questionMark) else { return nil }
        try discardNext(1) // discard '?'
        
        /*
         Query strings, by convention parse '+' as ' ' spaces
         */
        return try collect(until: .numberSign) { input in
            guard input == .plus else { return input }
            return .space
        }
    }

    /**
        https://tools.ietf.org/html/rfc3986#section-3.5

        A
        fragment identifier component is indicated by the presence of a
        number sign ("#") character and terminated by the end of the URI.
    */
    internal func parseFragment() throws -> [Byte]? {
        guard try checkLeadingBuffer(matches: .numberSign) else { return nil }
        try discardNext(1) // discard '#'
        return try collectRemaining()
    }
}
