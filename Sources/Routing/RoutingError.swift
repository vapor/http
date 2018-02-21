import Debugging

/// Errors that can be thrown while working with TCP sockets.
public struct RoutingError: Debuggable {
    public static let readableName = "Routing Error"
    public var identifier: String
    public var reason: String
    public var sourceLocation: SourceLocation?
    public var stackTrace: [String]

    /// Create a new TCP error.
    init(
        identifier: String,
        reason: String,
        source: SourceLocation
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = source
        self.stackTrace = RoutingError.makeStackTrace()
    }
}
