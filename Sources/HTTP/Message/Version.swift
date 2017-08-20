public struct Version: Codable {
    public var major: Int
    public var minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
}

