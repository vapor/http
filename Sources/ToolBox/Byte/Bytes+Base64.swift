import Foundation

/*
 // TODO: Temporary while foundation naming differs on linux
 */

#if !os(Linux)
    typealias NSData = Foundation.Data
#endif

extension Sequence where Iterator.Element == Byte {
    public var base64String: String {
        let bytes = [Byte](self)
        let data = NSData(bytes: bytes, count: bytes.count)
        // TODO: Add Link
        // This part from Crypto Essentials
        #if os(Linux)
            return data.base64EncodedString([])
        #else
            return data.base64EncodedString(options: [])
        #endif
    }
}
