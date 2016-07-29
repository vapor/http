import Core

extension Sequence where Iterator.Element == Byte {
    internal func percentDecodedString() throws -> String {
        guard let decoded = percentDecoded(self.array) else {
            throw URIParser.Error.invalidPercentEncoding
        }
        return decoded.string
    }
}
