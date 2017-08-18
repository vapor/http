/// The internal COW storage for queries
final class QueryStorage {
    let utf8String: UTF8String
    var cache = [Int : Int]()
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.utf8String = UTF8String(buffer: buffer)
    }
    
    init(utf8String: UTF8String) {
        self.utf8String = utf8String
    }
    
    init() {
        self.utf8String = UTF8String()
    }
}

/// Usable for queries in paths or query encoded forms
public struct Query : CustomDebugStringConvertible, RawRepresentable {
    let storage: QueryStorage
    
    /// The query's string representation
    public var rawValue: String {
        return self.storage.utf8String.makeString() ?? ""
    }
    
    /// Creates a new Query from a String
    public init?(rawValue: String) {
        self.storage = QueryStorage(utf8String: UTF8String(bytes: [UInt8](rawValue.utf8)))
    }
    
    /// A debug description is used for helping with debugging
    public var debugDescription: String {
        return self.rawValue
    }
    
    /// Creates a new query without unnecessary copies
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.storage = QueryStorage(buffer: buffer)
    }
    
    /// Creates a new query
    public init() {
        self.storage = QueryStorage()
    }
    
    /// Efficiently reads values from this query
    public subscript(key: String) -> String? {
        let stringKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let key = UTF8String(bytes: [UInt8](stringKey.utf8))
        
        if let position = storage.cache[key.hashValue] {
            // \r
            guard let nextIndex = storage.utf8String.index(of: 0x3d, offset: position) else {
                return nil
            }
            
            if storage.utf8String.byte(at: nextIndex) == 0x26 {
                return storage.utf8String.makeString(from: position, to: nextIndex &- 1)?.removingPercentEncoding
            } else {
                return storage.utf8String.makeString(from: position, to: nextIndex)?.removingPercentEncoding
            }
        }
        
        let slices = storage.utf8String.slice(by: 0x26)
        
        var offset = 0
        
        // ampersand
        for slice in slices {
            defer { offset = offset &+ slice.count }
            // equals
            if let index = slice.index(of: 0x3d) {
                let foundKey = UnsafeBufferPointer(start: slice.baseAddress, count: index)
                
                storage.cache[UTF8String.hashValue(of: foundKey)] = index
                
                if key == foundKey {
                    guard slice.count &- index > 1 else {
                        return ""
                    }
                    
                    let value = UnsafeBufferPointer(start: slice.baseAddress?.advanced(by: index &+ 1), count: slice.count &- index &- 1)
                    
                    return String(bytes: value, encoding: .utf8)?.removingPercentEncoding
                }
            } else if key == slice {
                return ""
            }
        }
        
        return nil
    }
}

extension Request {
    /// Extracts a query from the request
    public var form: Query {
        return self.body?.query ?? Query()
    }
}

extension BodyRepresentable {
    /// Extracts a query from any body
    public var query: Query? {
        guard let body = try? self.makeBody() else {
            return nil
        }
        
        return Query(buffer: UnsafeBufferPointer(start: body.buffer.baseAddress, count: body.buffer.count))
    }
}

