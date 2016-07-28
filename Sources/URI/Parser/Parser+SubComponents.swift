import Core

extension URIParser {
    /**
         https://tools.ietf.org/html/rfc3986#section-3.2

         authority   = [ userinfo "@" ] host [ ":" port ]
    */
    internal func parse(authority: [Byte]) throws -> (
        username: ArraySlice<Byte>?,
        auth: ArraySlice<Byte>?,
        host: ArraySlice<Byte>,
        port: ArraySlice<Byte>?
        ) {
            let comps = authority.split(
                separator: .at,
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            // 1 or 2, Host and Port is ALWAYS last component, otherwise empty which is ok
            guard let hostAndPort = comps.last else { return (nil, nil, [], nil) }
            let (host, port) = try parse(hostAndPort: hostAndPort.array)

            guard comps.count == 2, let userinfo = comps.first else { return (nil, nil, host, port) }
            let (username, auth) = try parse(userInfo: userinfo.array)
            return (username, auth, host, port)
    }

    /*
         Host:
         https://tools.ietf.org/html/rfc3986#section-3.2.2
         Port:
         https://tools.ietf.org/html/rfc3986#section-3.2.3
    */
    internal func parse(hostAndPort: [Byte]) throws -> (host: ArraySlice<Byte>, port: ArraySlice<Byte>?) {
        /**
             move in reverse looking for ':' or ']' or end of line

             if ':' then we have found a port, take bytes we have seen and add to port reference
             if ']' then we have IP Literal -- scan to end of string // TODO: Validate `[` closing?
             if end of line, then we have no port, just host. assign chunk of bytes to host
        */
        let hostStart = hostAndPort.startIndex
        let hostEnd = hostAndPort.endIndex - 1
        guard hostStart < hostEnd else { return ([], nil) }
        for i in (hostStart...hostEnd).lazy.reversed() {
            let byte = hostAndPort[i]
            if byte == .colon {
                // going reverse, if we found a colon BEFORE we found a ']' then it's a port
                let host = hostAndPort[hostStart..<i]
                // TODO: Check what happens w/ `example.com:` ... it MUST not crash
                let port = hostAndPort[(i + 1)...hostEnd]
                return (host, port)
            } else if byte == .rightSquareBracket {
                // square brackets ONLY for IP Literal
                // if we found right square bracket first, just complete to end
                // return remaining bytes to standard orientation
                // if we found a colon before this
                // the port would have been collected
                return (hostAndPort[hostStart...i], nil)
            }
        }

        return (hostAndPort[hostStart...hostEnd], nil)
    }

    /**
         https://tools.ietf.org/html/rfc3986#section-3.2.1

         The userinfo subcomponent may consist of a user name and, optionally,
         scheme-specific information about how to gain authorization to access
         the resource.  The user information, if present, is followed by a
         commercial at-sign ("@") that delimits it from the host.

         userinfo    = *( unreserved / pct-encoded / sub-delims / ":" )

         Use of the format "user:password" in the userinfo field is
         deprecated.  Applications should not render as clear text any data
         after the first colon (":") character found within a userinfo
         subcomponent unless the data after the colon is the empty string
         (indicating no password).  Applications may choose to ignore or
         reject such data when it is received as part of a reference and
         should reject the storage of such data in unencrypted form.  The
         passing of authentication information in clear text has proven to be
         a security risk in almost every case where it has been used.
    */
    internal func parse(userInfo: [Byte]) throws -> (username: ArraySlice<Byte>, auth: ArraySlice<Byte>?) {
        /**
             Iterate as 'username' until we find `:`, then give `auth` remaining bytes
        */
        let split = userInfo.split(separator: .colon, maxSplits: 1)
        guard !split.isEmpty else { return ([], nil) }
        let username = split[0]
        guard split.count == 2 else { return (username, nil) }
        return (username, split[1])
    }
}
