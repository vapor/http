// MARK: Message

extension MediaType : CustomStringConvertible {
    func bytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(type.count + subtype.count + 128)
        
        bytes.append(contentsOf: typeBytes)
        bytes.append(.forwardSlash)
        bytes.append(contentsOf: subtypeBytes)
        
        for parameter in parameters {
            bytes.append(.semicolon)
            bytes.append(.space)
            bytes += Array(parameter.key.utf8)
            bytes.append(.equals)
            bytes += Array(parameter.value.utf8)
        }
        
        return bytes
    }
    
    /// :nodoc:
    public var description: String {
        return String(bytes: bytes(), encoding: .utf8) ?? ""
    }
}
