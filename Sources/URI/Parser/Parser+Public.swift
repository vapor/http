import Core

extension URIParser {
    /**
        Parse an array of received bytes into a URI
    */
    public static func parse(uri: Bytes) throws -> URI {
        let parser = URIParser(bytes: uri) // TODO: Retain splice format
        return try parser.parse()
    }
}
