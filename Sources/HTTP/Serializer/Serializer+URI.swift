extension String: CustomStringConvertible {
    public var description: String { return self }
}

extension URI {
    public mutating func append(query appendQuery: [String: CustomStringConvertible]) {
        guard !appendQuery.isEmpty else { return }
        let appendQuery = appendQuery
            .map { key, value in
                return "\(key)=\(value)"
            }
            .joined(separator: "&")

        var new = ""
        if let existing = query {
            new += existing
            new += "&"
        }
        new += appendQuery

        query = new
    }
}
