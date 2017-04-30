extension URI {
    /**
        Attempts to parse a given string as a URI
    */
    public init(_ str: String) throws {
        self = URIParser.shared.parse(bytes: str.makeBytes())
    }
}

extension URI: CustomStringConvertible {
    public var description: String {
        var s = ""
        if !scheme.isEmpty { s += "\(scheme)://" }
        if let userInfo = userInfo { s += "\(userInfo)@" }
        if !hostname.isEmpty { s += "\(hostname)" }
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

extension String {
    public var percentDecoded: String {
        return self
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding ?? ""
    }
}
