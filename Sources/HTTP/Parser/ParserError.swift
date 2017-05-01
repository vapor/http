/// Errors that may be encountered while parsing
public enum ParserError: Error {
    case invalidMessage
    case streamClosed
}
