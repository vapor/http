import Core

extension Sequence where Iterator.Element == Byte {
    internal func percentDecodedString() throws -> String {
        guard let decoded = self.array.percentDecoded() else {
            throw URIParser.Error.invalidPercentEncoding
        }
        return decoded.makeString()
    }
}
