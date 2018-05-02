import Debugging

/// Errors that can be thrown while working with HTTP.
public struct HTTPError: Debuggable {
    /// See `Debuggable`.
    public static let readableName = "HTTP Error"

    /// See `Debuggable`.
    public let identifier: String

    /// See `Debuggable`.
    public var reason: String

    /// See `Debuggable`.
    public var sourceLocation: SourceLocation?

    /// See `Debuggable`.
    public var stackTrace: [String]

    /// Creates a new `HTTPError`.
    public init(
        identifier: String,
        reason: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = HTTPError.makeStackTrace()
    }
}

/// For printing un-handleable errors.
func ERROR(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    print("[ERROR] [HTTP] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
}

/// For printing debug info.
func DEBUG(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    #if VERBOSE
    print("[VERBOSE] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
    #endif
}

internal func debugOnly(_ body: () -> Void) {
    assert({ body(); return true }())
}
