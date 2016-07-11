public enum SMTPClientError: ErrorProtocol {
    case initializationFailed(code: Int, greeting: String)
    case initializationFailed554(reason: String)
    case invalidMultilineReplyCode(expected: Int, got: Int)
    case invalidEhloHeader
}
