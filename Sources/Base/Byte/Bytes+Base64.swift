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
            let encodedData = data.base64EncodedData([])
            var encodedBytes = Bytes(repeating: 0, count: encodedData.length)
            encodedData.getBytes(to: &encodedBytes, count: encodedBytes.count)
        #else
            let encodedData = data.base64EncodedData(options: [])
            var encodedBytes = Bytes(repeating: 0, count: encodedData.count)
            encodedData.copyBytes(to: &encodedBytes, count: encodedData.count)
        #endif

        return encodedBytes
    }
}

extension String {
    public var base64DecodedString: String {
        #if os(Linux)
        guard let data = Data(base64EncodedString: self) else { return "" }
        #else
        guard let data = Data(base64Encoded: self) else { return "" }
        #endif



        var bytes = Bytes(repeating: 0, count: data.count)
        #if os(Linux)
            data.getBytes(to: &bytes, count: data.length)
        #else
            data.copyBytes(to: &bytes, count: data.count)
        #endif
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
