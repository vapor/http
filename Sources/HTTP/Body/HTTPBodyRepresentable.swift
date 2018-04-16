/// Can be converted to an `HTTPBody`.
public protocol HTTPBodyRepresentable {
    /// Converts self to an HTTP body.
    func convertToHTTPBody() throws -> HTTPBody
}

/// `String` can be represented as an `HTTPBody`.
extension String: HTTPBodyRepresentable {
    /// See `HTTPBodyRepresentable`.
    public func convertToHTTPBody() throws -> HTTPBody {
        return HTTPBody(string: self)
    }
}

/// `Data` can be represented as an `HTTPBody`.
extension Data: HTTPBodyRepresentable {
    /// See `HTTPBodyRepresentable`.
    public func convertToHTTPBody() throws -> HTTPBody {
        return HTTPBody(data: self)
    }
}

/// `StaticString` can be represented as an `HTTPBody`.
extension StaticString: HTTPBodyRepresentable {
    /// See `HTTPBodyRepresentable`.
    public func convertToHTTPBody() throws -> HTTPBody {
        return HTTPBody(staticString: self)
    }
}


/// `ByteBuffer` can be represented as an `HTTPBody`.
extension ByteBuffer: HTTPBodyRepresentable {
    /// See `HTTPBodyRepresentable`.
    public func convertToHTTPBody() throws -> HTTPBody {
        return HTTPBody(buffer: self)
    }
}
