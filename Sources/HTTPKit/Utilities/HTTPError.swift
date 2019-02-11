/// Errors that can be thrown while working with HTTP.
public struct HTTPError: Error {
    public enum Reason {
        case noContent
        case noContentType
        case unknownContentType
        case maxBodySize
    }
    
    /// See `Debuggable`.
    public let reason: Reason

    /// Creates a new `HTTPError`.
    public init(
        _ reason: Reason
    ) {
        self.reason = reason
    }
}
