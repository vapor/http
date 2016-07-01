public protocol HTTPBodyRepresentable {
    func makeBody() -> HTTPBody
}

extension String: HTTPBodyRepresentable {
    public func makeBody() -> HTTPBody {
        return HTTPBody(self)
    }
}

extension HTTPBody: HTTPBodyRepresentable {
    public func makeBody() -> HTTPBody {
        return self
    }
}
