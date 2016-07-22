extension EmailAddress: ExpressibleByStringLiteral {
    /*
         Turn string into EmailAddress
         
            == EmailAddress(name: nil, address: self)
    */
    public init(stringLiteral string: String) {
        self.init(name: nil, address: string)
    }

    /*
         Turn string into EmailAddress

         == EmailAddress(name: nil, address: self)
    */
    public init(extendedGraphemeClusterLiteral string: String){
        self.init(name: nil, address: string)
    }

    /*
         Turn string into EmailAddress

         == EmailAddress(name: nil, address: self)
    */
    public init(unicodeScalarLiteral string: String){
        self.init(name: nil, address: string)
    }
}
