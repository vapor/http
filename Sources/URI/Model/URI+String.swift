extension URI {
    /**
        Attempts to parse a given string as a URI
    */
    public init(_ str: String) throws {
        self = try URIParser.parse(bytes: str.utf8.array)
    }
}

extension URI: CustomStringConvertible {
    public var description: String {
        var s = ""
        if !scheme.isEmpty { s += "\(scheme)://" }
        if let userInfo = userInfo { s += "\(userInfo)@" }
        if !host.isEmpty { s += "\(host)" }
        if let port = port { s += ":\(port)" }
        if !path.isEmpty { s += path.begin(with: "/") }
        if let query = query { s += "?\(query)" }
        if let fragment = fragment { s += "#\(fragment)" }
        return s
    }
}

extension String {
    fileprivate func begin(with expectation: String) -> String {
        if hasPrefix(expectation) { return self }
        return expectation + self
    }
}
