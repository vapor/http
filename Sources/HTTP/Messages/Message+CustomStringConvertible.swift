extension Request: CustomStringConvertible {
    public var description: String {
        var d: [String] = []

        d += ["\(type(of: self))"]
        d += ["- Method: " + method.description]
        d += ["- Version: " + version.description]
        d += ["- URI: " + uri.description]
        d += ["- Headers:"]
        d += [headers.map { field, val in "\t\(field): \(val)" } .joined(separator: "\n")]
        d += ["- Body:"]
        d += ["\t\(body.bytes?.makeString() ?? "n/a")"]

        return d.joined(separator: "\n")
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        var d: [String] = []
        
        d += ["\(type(of: self))"]
        d += ["- Version: " + version.description]
        d += ["- Status: " + status.statusCode.description]
        d += ["- Headers:"]
        d += [headers.map { field, val in "\t\(field): \(val)" } .joined(separator: "\n")]
        d += ["- Body:"]
        d += ["\t\(body.bytes?.makeString() ?? "n/a")"]
        
        return d.joined(separator: "\n")
    }
}

