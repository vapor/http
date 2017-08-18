/// The HTTP response status
///
/// TODO: Add more status codes
public enum Status : ExpressibleByIntegerLiteral {
    /// upgrade is used for upgrading the connection to a new protocol, such as WebSocket or HTTP/2
    case upgrade

    /// A successful response
    case ok

    /// The resource has not been found
    case notFound

    /// An internal error occurred
    case internalServerError

    /// Something yet to be implemented
    case custom(code: Int, message: String)

    /// Checks of two Statuses are equal
    public static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.code == rhs.code
    }

    /// The HTTP status code
    public var code: Int {
        switch self {
        case .upgrade: return 101
        case .ok: return 200
        case .notFound: return 404
        case .internalServerError: return 500
        case .custom(let code, _): return code
        }
    }

    /// Creates a new (custom) status code
    public init(_ code: Int, message: String = "") {
        switch code {
        case 101: self = .upgrade
        case 200: self = .ok
        case 404: self = .notFound
        case 500: self = .internalServerError
        default: self = .custom(code: code, message: message)
        }
    }

    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}
