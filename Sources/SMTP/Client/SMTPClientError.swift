/*:
    Errors associated w/ SMTPClient
*/
public enum SMTPClientError: Swift.Error {
    /*
        Multiline replies must have same reply code. If different, throws this error
    */
    case invalidMultilineReply(expected: Int, got: Int, replies: [String])

    /*
        The useranme failed to authorize
    */
    case invalidUsername(code: Int, reply: String)

    /*
        The password failed to authorize
    */
    case invalidPassword(code: Int, reply: String)

    /*
        Authorization was not approved
    */
    case authorizationFailed(code: Int, reply: String)

    /*
        Received unexpected error coded
    */
    case unexpectedReply(expected: Int, got: Int, replies: [String], initiator: String)

    /*
         This error is thrown when the SMTP server doesn't support any of SMTP's available auth methods.
         If this happens and it is a reasonable authorization mechanism, please contact
         maintainer and file an issue.
    */
    case unsupportedAuth(supportedByServer: [String], supportedBySMTP: [String])

    /*
        The EHLO and subsequent HELO attempt failed
    */
    case initiationFailed(code: Int, replies: [String])

    /*
        Didn't receive expected greeting from server
    */
    case missingGreeting

    /*
        The greeting received by a server indicates that it is invalid
    */
    case invalidGreeting(code: Int, greeting: String)

    /*
        Quitting the SMTP session failed
    */
    case quitFailed(code: Int, reply: String)
}

extension SMTPClientError {
    /*
        Error Code, if applicable
    */
    public var code: Int {
        switch self {
        case let .invalidMultilineReply(expected: _, got: errorCode, replies: _):
            return errorCode
        case let .invalidUsername(code: errorCode, reply: _):
            return errorCode
        case let .invalidPassword(code: errorCode, reply: _):
            return errorCode
        case let .authorizationFailed(code: errorCode, reply: _):
            return errorCode
        case let .unexpectedReply(expected: _, got: errorCode, replies: _, initiator: _):
            return errorCode
        case .unsupportedAuth(supportedByServer: _, supportedBySMTP: _):
            return -1
        case let .initiationFailed(code: errorCode, replies: _):
            return errorCode
        case .missingGreeting:
            return -2
        case let .invalidGreeting(code: errorCode, greeting: _):
            return errorCode
        case let .quitFailed(code: errorCode, reply: _):
            return errorCode
        }
    }

    /*
        Error replies, if available.
    */
    public var replies: [String] {
        switch self {
        case let .invalidMultilineReply(expected: _, got: _, replies: replies):
            return replies
        case let .invalidUsername(code: _, reply: reply):
            return [reply]
        case let .invalidPassword(code: _, reply: reply):
            return [reply]
        case let .authorizationFailed(code: _, reply: reply):
            return [reply]
        case let .unexpectedReply(expected: _, got: _, replies: replies, initiator: _):
            return replies
        case .unsupportedAuth(supportedByServer: _, supportedBySMTP: _):
            return []
        case let .initiationFailed(code: _, replies: replies):
            return replies
        case .missingGreeting:
            return []
        case let .invalidGreeting(code: _, greeting: greeting):
            return [greeting]
        case let .quitFailed(code: _, reply: reply):
            return [reply]
        }
    }
}
