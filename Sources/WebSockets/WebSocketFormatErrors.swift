import HTTP

extension WebSocket {
    public enum FormatError: Swift.Error {
        case missingSecKeyHeader
        case missingSecAcceptHeader
        case invalidSecAcceptHeader
        case missingUpgradeHeader
        case missingConnectionHeader
        case invalidURI
        case invalidOrUnsupportedVersion
        case invalidOrUnsupportedStatus(Status)
    }
}

extension WebSocket.FormatError: Equatable {
    public static func ==(lhs: WebSocket.FormatError, rhs: WebSocket.FormatError) -> Bool {
        switch (lhs, rhs) {
        case (.missingSecKeyHeader, .missingSecKeyHeader):
            return true
        case (.missingSecAcceptHeader, .missingSecAcceptHeader):
            return true
        case (.invalidSecAcceptHeader, .invalidSecAcceptHeader):
            return true
        case (.missingUpgradeHeader, .missingUpgradeHeader):
            return true
        case (.missingConnectionHeader, .missingConnectionHeader):
            return true
        case (.invalidURI, .invalidURI):
            return true
        case (.invalidOrUnsupportedVersion, .invalidOrUnsupportedVersion):
            return true
        case (.invalidOrUnsupportedStatus(let lhsStatus), .invalidOrUnsupportedStatus(let rhsStatus)):
            return lhsStatus == rhsStatus
        default:
            return false
        }
    }
}

