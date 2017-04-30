import Core

private let GET = "GET".makeBytes()
private let POST = "POST".makeBytes()
private let PUT = "PUT".makeBytes()
private let PATCH = "PATCH".makeBytes()
private let DELETE = "DELETE".makeBytes()
private let OPTIONS = "OPTIONS".makeBytes()
private let HEAD = "HEAD".makeBytes()
private let CONNECT = "CONNECT".makeBytes()
private let TRACE = "TRACE".makeBytes()

extension Method {
    init(uppercased method: Bytes) {
        switch method {
        case GET:
            self = .get
        case POST:
            self = .post
        case PUT:
            self = .put
        case PATCH:
            self = .patch
        case DELETE:
            self = .delete
        case OPTIONS:
            self = .options
        case HEAD:
            self = .head
        case CONNECT:
            self = .connect
        case TRACE:
            self = .trace
        default:
            self = .other(method: method.makeString())
        }
    }
}
