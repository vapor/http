extension URI {
    /**
        Attempts to parse a given string as a URI
    */
    public init(_ str: String) throws {
        self = try URIParser.parse(bytes: str.utf8.array)
    }
}
