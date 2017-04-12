extension Message: CustomStringConvertible {
    public var description: String {
        var d: [String] = []

        d += ["\(type(of: self))"]
        d += ["- " + startLine]
        d += ["- Headers:"]
        d += [headers.map { field, val in "\t\(field): \(val)" } .joined(separator: "\n")]
        d += ["- Body:"]
        d += ["\t\(body.bytes?.makeString() ?? "n/a")"]

        return d.joined(separator: "\n")
    }
}

