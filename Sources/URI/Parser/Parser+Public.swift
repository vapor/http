import Core

extension URIParser {
    /**
        Parse an array of received bytes into a URI
    */
    public static func parse(bytes: Bytes, existingHost: String? = nil) throws -> URI {
        let parser = URIParser(bytes: bytes, existingHost: existingHost)
        return try parser.parse()
    }
}
