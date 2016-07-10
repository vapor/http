extension EmailAddress: StringLiteralConvertible {
    public init(stringLiteral string: String) {
        self.init(name: nil, address: string)
    }

    public init(extendedGraphemeClusterLiteral string: String){
        self.init(name: nil, address: string)
    }

    public init(unicodeScalarLiteral string: String){
        self.init(name: nil, address: string)
    }
}
