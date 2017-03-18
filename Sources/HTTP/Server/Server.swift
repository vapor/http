import Transport

public protocol Server: InternetStream {
    func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws
}

extension Server {
    public func start(_ responder: Responder) throws {
        try start(responder) { error in
            print("Server error: \(error)")
        }
    }
}
