public struct EmailAddress {
    public let name: String?
    public let address: String

    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }
}
