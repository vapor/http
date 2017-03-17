import Core
import Foundation

extension Sequence where Iterator.Element == Byte {
    internal func percentDecodedString() throws -> String {
        guard let decoded = makeString().removingPercentEncoding else {
            throw URIParser.Error.invalidPercentEncoding
        }
        return decoded
    }
}
