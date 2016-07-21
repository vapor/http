public typealias ServerErrorHandler = (ServerError) -> ()

public enum ServerError: Swift.Error {
    case bind(host: String, port: Int, Swift.Error)
    case accept(Swift.Error)
    case respond(Swift.Error)
    case dispatch(Swift.Error)
    case unknown(Swift.Error)
}
