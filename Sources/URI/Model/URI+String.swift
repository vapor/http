extension URI {
    /**
        Attempts to parse a given string as a URI
    */
    public init(_ str: String) throws {
        self = try URIParser.parse(uri: str.utf8.array)
        guard port == nil else { return }
        // if no port, try scheme default if possible
        port = defaultPort
    }
}
