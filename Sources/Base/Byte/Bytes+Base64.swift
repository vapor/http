import Foundation

extension Sequence where Iterator.Element == Byte {
    public var base64String: String {
        let bytes = [Byte](self)
        let data = NSData(bytes: bytes)
        #if os(Linux)
            return data.base64EncodedString([])
        #else
            return data.base64EncodedString(options: [])
        #endif
    }
}


extension NSData {
    // TODO: Add Link
    // This part from Crypto Essentials
    convenience init(bytes: [UInt8]) {
        self.init(bytes: bytes, length: bytes.count)
    }
}
