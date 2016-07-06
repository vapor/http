extension Sequence {
    public var array: [Iterator.Element] {
        return Array(self)
    }
}
