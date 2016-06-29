extension Equatable {
    public func equals(any: Self...) -> Bool {
        return any.contains(self)
    }
    public func equals(any: [Self]) -> Bool {
        return any.contains(self)
    }
}
