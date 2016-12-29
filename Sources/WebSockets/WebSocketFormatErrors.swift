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
