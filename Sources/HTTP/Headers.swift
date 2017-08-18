/// Header keys have the same properties that values have
public typealias HeaderValue = HeaderKey

fileprivate let cookieKey: HeaderKey = "Cookie"
fileprivate let setCookieKey: HeaderKey = "Set-Cookie"

extension String {
    init?(_ value: HeaderValue) {
        self = value.rawValue
    }
}

/// An HTTP header key
public struct HeaderKey : Hashable, CustomDebugStringConvertible, CodingKey, Codable, RawRepresentable {
    public init?(rawValue: String) {
        self.init(rawValue)
    }
    
    /// Returns the string in this key
    public var rawValue: String {
        return utf8String.makeString() ?? ""
    }
    
    public var stringValue: String {
        return rawValue
    }
    
    public var intValue: Int?
    
    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        
        self.init(string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
    
    internal var utf8String: UTF8String
    
    /// Accesses the internal byte buffer
    public var bytes: [UInt8] {
        guard let buffer = utf8String.makeBuffer() else {
            return []
        }
        
        return Array(buffer)
    }
    
    /// Hashable
    public var hashValue: Int {
        return utf8String.hashValue
    }
    
    /// Compares two headers
    public static func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
        return lhs.utf8String == rhs.utf8String
    }
    
    /// Creates a new HeaderKey from a byte buffer
    public init(bytes: [UInt8]) {
        self.utf8String = UTF8String(bytes: bytes)
    }
    
    public init?(intValue: Int) {
        return nil
    }
    
    public init?(stringValue: String) {
        self.init(stringValue)
    }
    
    public init(_ string: String) {
        self.init(bytes: [UInt8](string.utf8))
    }
    
    /// Creates a new HeaderKey from a bufferpointer
    public init(buffer: UnsafeBufferPointer<UInt8>) {
        self.utf8String = UTF8String(buffer: buffer)
    }
    
    /// Debugging helper
    public var debugDescription: String {
        return self.rawValue
    }
    
    public static func +(lhs: HeaderKey, rhs: HeaderKey) -> HeaderKey {
        return HeaderKey(bytes: lhs.bytes + rhs.bytes)
    }
}

extension String {
    public init?(_ value: HeaderValue?) {
        guard let value = value else {
            return nil
        }
        
        self = value.rawValue
    }
}

extension Int {
    public init?(_ value: HeaderValue?) {
        guard let value = value, let int = Int(value.rawValue) else {
            return nil
        }
        
        self = int
    }
}

extension HeaderKey : ExpressibleByStringLiteral {
    /// Instantiate a HeaderKey from a String literal
    public init(stringLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    /// Instantiate a HeaderKey from a String literal
    public init(unicodeScalarLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    /// Instantiate a HeaderKey from a String literal
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
}

/// The internal storage of headers for COW
fileprivate final class HeadersStorage {
    /// The internal storage
    var serialized: [UInt8]
    
    /// A cache of all headers
    var hashes = [(hash: Int, position: Int)]()
    
    /// Instantiates the headerstorage from a bufferpointer
    init(serialized: UnsafeBufferPointer<UInt8>) {
        self.serialized = Array(serialized)
    }
    
    init() {
        self.serialized = []
        self.hashes = []
    }
}

/// HTTP headers
public struct Headers : ExpressibleByDictionaryLiteral, CustomDebugStringConvertible, Sequence, Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: HeaderKey.self)
        
        let pairs = try container.allKeys.map { key in
            return (key, try container.decode(HeaderValue.self, forKey: key))
        }
        
        self.init(dictionaryElements: pairs)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: HeaderKey.self)
        
        for (key, value) in self {
            try container.encode(value, forKey: key)
        }
    }
    
    /// The internal storage
    private let storage: HeadersStorage
    
    public var debugDescription: String {
        return String(bytes: self.buffer, encoding: .utf8) ?? ""
    }
    
    public init(serialized: UnsafeBufferPointer<UInt8>) {
        self.storage = HeadersStorage(serialized: serialized)
    }
    
    public var buffer: UnsafeBufferPointer<UInt8> {
        return UnsafeBufferPointer(start: storage.serialized, count: storage.serialized.count)
    }
    
    public func makeIterator() -> AnyIterator<(HeaderKey, HeaderValue)> {
        // scan all
        search(for: nil)
        
        var iterator = storage.hashes.makeIterator()
        var length: Int = storage.serialized.count
        var currentPosition = storage.hashes.last?.position ?? 0
        let pointer = UnsafePointer(storage.serialized)
        var newPointer: UnsafePointer<UInt8>!
        
        return AnyIterator {
            guard let (_, next) = iterator.next() else {
                return nil
            }
            
            newPointer = pointer.advanced(by: next)
            newPointer.peek(until: 0x3a, length: &length, offset: &currentPosition)
            
            guard currentPosition > 0 else {
                return nil
            }
            
            guard newPointer.pointee == 0x20 else {
                return nil
            }
            
            let key = HeaderKey(buffer: newPointer.buffer(until: &currentPosition))
            
            // Scan until \r so we capture the string
            newPointer.peek(until: 0x0d, length: &length, offset: &currentPosition)
            
            guard newPointer.pointee == 0x0a else {
                return nil
            }
            
            guard currentPosition > 1 else {
                return nil
            }
            
            currentPosition = currentPosition &- 1
            
            let value = HeaderValue(buffer: newPointer.buffer(until: &currentPosition))
            
            return (key, value)
        }
    }
    
    /// Indexes the headers
    @discardableResult
    fileprivate func search(for key: HeaderKey?) -> HeaderValue? {
        var currentPosition = storage.hashes.last?.position ?? 0
        
        let startPointer = UnsafePointer(storage.serialized)
        var length: Int = storage.serialized.count
        var pointer = startPointer.advanced(by: currentPosition)
        var keyEnd = 0
        
        while true {
            let start = startPointer.distance(to: pointer)
            let keyPointer = pointer
            // colon
            pointer.peek(until: 0x3a, length: &length, offset: &currentPosition)
            
            keyEnd = currentPosition &- 1
            
            guard keyEnd > 0 else {
                return nil
            }
            
            guard pointer.pointee == 0x20 else {
                return nil
            }
            
            // Scan until \r so we capture the string
            pointer.peek(until: 0x0d, length: &length, offset: &currentPosition)
            
            guard pointer.pointee == 0x0a else {
                return nil
            }
            
            guard currentPosition > 1 else {
                return nil
            }
            
            let keyBuffer = UnsafeBufferPointer(start: keyPointer, count: keyEnd)
            
            self.storage.hashes.append((UTF8String.hashValue(of: keyBuffer), start))
            
            if let key = key {
                if key.bytes.count == keyEnd, key.utf8String == keyBuffer {
                    currentPosition = currentPosition &- 1
                    let buffer = pointer.buffer(until: &currentPosition)
                    return HeaderValue(buffer: buffer)
                }
            }
            
            // skip \n
            pointer = pointer.advanced(by: 1)
        }
    }
    
    public subscript(key: HeaderKey) -> HeaderValue? {
        get {
            if let position = storage.hashes.first(where: { $0.0 == key.hashValue })?.position {
                let start = position &+ key.bytes.count &+ 2
                
                guard start < storage.serialized.count else {
                    return nil
                }
                
                for i in start..<storage.serialized.count {
                    // \r
                    guard storage.serialized[i] != 0x0d else {
                        return HeaderValue(buffer: UnsafeBufferPointer(start: UnsafePointer(storage.serialized).advanced(by: start), count: i &- start))
                    }
                }
                
                return nil
            }
            
            return self.search(for: key)
        }
        // TODO: UPDATE CACHE
        set {
            _ = self[key]
            
            if let index = storage.hashes.index(where: { $0.0 == key.hashValue }) {
                let position = storage.hashes[index].position
                
                defer { storage.hashes = [] }
                
                if let newValue = newValue {
                    let position = storage.hashes[index].position
                    
                    let start = position &+ key.bytes.count &+ 2
                    
                    guard start + 2 < storage.serialized.count else {
                        return
                    }
                    
                    var final: Int?
                    
                    finalChecker: for i in start..<storage.serialized.count {
                        // \r
                        if storage.serialized[i] == 0x0d {
                            final = i
                            break finalChecker
                        }
                    }
                    
                    if let final = final {
                        storage.serialized.replaceSubrange(start..<final, with: newValue.bytes)
                    }
                } else {
                    let endPosition = (storage.hashes.count > index) ? storage.hashes[index + 1].position : storage.serialized.endIndex
                    
                    storage.serialized.removeSubrange(position..<endPosition)
                }
                // overwrite or remove on `nil`
            } else if let newValue = newValue {
                storage.hashes.append((key.hashValue, storage.serialized.endIndex))
                storage.serialized.append(contentsOf: key.bytes)
                
                // ": "
                storage.serialized.append(0x3a)
                storage.serialized.append(0x20)
                storage.serialized.append(contentsOf: newValue.bytes)
                storage.serialized.append(0x0d)
                storage.serialized.append(0x0a)
            }
            
            // Clean cache
            storage.hashes = []
        }
    }
    
    /// Creates a new empty header
    public init() {
        self.storage = HeadersStorage()
    }
    
    /// Creates a new Header from a dictionary literal
    public init(dictionaryElements elements: [(HeaderKey, HeaderValue)]) {
        self.storage = HeadersStorage()
        
        for (key, value) in elements {
            self[key] = value
        }
    }
    
    /// Creates a new Header from a dictionary literal
    public init(dictionaryLiteral elements: (HeaderKey, HeaderValue)...) {
        self.init(dictionaryElements: elements)
    }
}


// MARK - Copy for swift inline optimization

extension UnsafePointer where Pointee == UInt8 {
    fileprivate func buffer(until length: inout Int) -> UnsafeBufferPointer<UInt8> {
        guard length > 0 else {
            return UnsafeBufferPointer<UInt8>(start: nil, count: 0)
        }
        
        // - 1 for the skipped byte
        return UnsafeBufferPointer(start: self.advanced(by: -length), count: length &- 1)
    }
    
    fileprivate mutating func peek(until byte: UInt8, length: inout Int, offset: inout Int) {
        offset = 0
        defer { length = length &- offset }
        
        while offset &+ 4 < length {
            if self[0] == byte {
                offset = offset &+ 1
                self = self.advanced(by: 1)
                return
            }
            if self[1] == byte {
                offset = offset &+ 2
                self = self.advanced(by: 2)
                return
            }
            if self[2] == byte {
                offset = offset &+ 3
                self = self.advanced(by: 3)
                return
            }
            offset = offset &+ 4
            defer { self = self.advanced(by: 4) }
            if self[3] == byte {
                return
            }
        }
        
        if offset < length, self[0] == byte {
            offset = offset &+ 1
            self = self.advanced(by: 1)
            return
        }
        if offset &+ 1 < length, self[1] == byte {
            offset = offset &+ 2
            self = self.advanced(by: 2)
            return
        }
        if offset &+ 2 < length, self[2] == byte {
            offset = offset &+ 3
            self = self.advanced(by: 3)
            return
        }
        
        self = self.advanced(by: length &- offset)
        offset = length
    }
}

