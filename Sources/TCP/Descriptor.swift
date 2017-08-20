public struct Descriptor: Hashable {
    public var raw: Int32

    public var hashValue: Int {
        return Int(raw)
    }

    public static func ==(lhs: Descriptor, rhs: Descriptor) -> Bool {
        return lhs.raw == rhs.raw

    }
}
