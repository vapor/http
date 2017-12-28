// MARK: Message

extension MediaType : CustomStringConvertible {
    func bytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(type.count + subtype.count + 128)
        
        bytes.append(contentsOf: typeBytes)
        bytes.append(.forwardSlash)
        bytes.append(contentsOf: subtypeBytes)
        
        var firstParameter = true
        
        for parameter in parameters {
            bytes += Array(parameter.key.utf8)
            bytes.append(.equals)
            bytes += Array(parameter.value.utf8)
            
            if !firstParameter {
                bytes.append(.semicolon)
            }
            
            firstParameter = false
        }
        
        return bytes
    }
    
    /// :nodoc:
    public var description: String {
        return String(bytes: bytes(), encoding: .utf8) ?? ""
    }
}
