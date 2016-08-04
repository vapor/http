public protocol BodyRepresentable {
    func makeBody() -> Body
}

extension String: BodyRepresentable {
    public func makeBody() -> Body {
        return Body(self)
    }
}

extension Body: BodyRepresentable {
    public func makeBody() -> Body {
        return self
    }
}
