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

    public var base64Data: Bytes {
        let bytes = [Byte](self)
        let data = NSData(bytes: bytes)
        #if os(Linux)
            let encodedData = data.base64EncodedData([]) as NSData
        #else
            let encodedData = data.base64EncodedData(options: []) as NSData
        #endif
        var encodedBytes = Bytes(repeating: 0, count: encodedData.length)
        encodedData.getBytes(&encodedBytes,  length: encodedData.length)

        return encodedBytes
    }
}

extension String {
    public var base64DecodedString: String {
        guard let data = NSData(base64Encoded: self, options: []) else { return "" }
        var bytes = Bytes(repeating: 0, count: data.length)
        data.getBytes(&bytes,  length: data.length)
        return bytes.string
    }
}

extension NSData {
    // TODO: Add Link
    // This part from Crypto Essentials
    convenience init(bytes: [UInt8]) {
        self.init(bytes: bytes, length: bytes.count)
    }
}
