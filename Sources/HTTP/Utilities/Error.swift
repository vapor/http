import Debugging
import Foundation
import COperatingSystem

/// Errors that can be thrown while working with HTTP.
public struct HTTPError: Debuggable {
    public static let readableName = "HTTP Error"
    public let identifier: String
    public var reason: String
    public var sourceLocation: SourceLocation?
    public var stackTrace: [String]

    public init(
        identifier: String,
        reason: String,
        source: SourceLocation
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = source
        self.stackTrace = HTTPError.makeStackTrace()
    }

    public static func invalidMessage(
        source: SourceLocation
    ) -> Error {
        return HTTPError(
            identifier: "invalidMessage",
            reason: "Unable to parse invalid HTTP message.",
            source: source
        )
    }

    public static func contentRequired(
        _ type: Any.Type,
        source: SourceLocation
    ) -> Error {
        return HTTPError(
            identifier: "contentRequired",
            reason: "\(type) content required.",
            source: source
        )
    }
}

/// For printing un-handleable errors.
func ERROR(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    print("[HTTP] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
}

/// For printing debug info.
func DEBUG(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    #if VERBOSE
    print("[VERBOSE] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
    #endif
}

extension UnsafeMutableBufferPointer {
    /// Calls `.initialize(from:)` and asserts there is no remaining data.
    func initializeAssertingNoRemainder<S>(from sequence: S) where S: Sequence, S.Element == Element {
        var (it, _) = initialize(from: sequence)
        assert(it.next() == nil)
    }
}

