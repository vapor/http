#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation

/// Keeps track of a set of data, related to a UTF8 String, using COW
internal class UTF8StringBuffer {
    internal let bytes: UnsafeMutablePointer<UInt8>?
    
    internal let count: Int
    
    internal let hashValue: Int
    
    init() {
        self.bytes = nil
        self.count = 0
        self.hashValue = 0
    }
    
    deinit {
        self.bytes?.deinitialize(count: self.count)
        self.bytes?.deallocate(capacity: self.count)
    }
    
    init(_ bytes: [UInt8]) {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
        pointer.initialize(from: bytes, count: bytes.count)
        self.count = bytes.count
        self.bytes = pointer
        var hashValue = 0
        
        if bytes.count > 0 {
            for i in 0..<bytes.count {
                hashValue = 31 &* hashValue &+ numericCast(bytes[i])
            }
        }
        
        self.hashValue = hashValue
    }
}

internal struct UTF8String : Hashable {
    var hashValue: Int {
        return buffer.hashValue
    }
    
    var firstByte: UInt8? {
        guard buffer.count > 0 else {
            return nil
        }
        
        return buffer.bytes?[0]
    }
    
    var byteCount: Int {
        return buffer.count
    }
    
    static func hashValue(of buffer: UnsafeBufferPointer<UInt8>) -> Int {
        guard buffer.count > 0 else {
            return 0
        }
        
        var hashValue = 0
        
        for i in 0..<buffer.count {
            hashValue = 31 &* hashValue &+ numericCast(buffer[i])
        }
        
        return hashValue
    }
    
    func index(of byte: UInt8, offset: Int) -> Int? {
        guard let pointer = self.buffer.bytes?.advanced(by: offset) else {
            return nil
        }
        
        guard let index = UnsafeBufferPointer(start: pointer, count: self.buffer.count &- offset).index(of: byte) else {
            return nil
        }
        
        return index &+ offset
    }
    
    func byte(at index: Int) -> UInt8? {
        return self.buffer.bytes?.advanced(by: index).pointee
    }
    
    func slice(by byte: UInt8) -> [UnsafeBufferPointer<UInt8>] {
        guard let address = buffer.bytes else {
            return []
        }
        
        var pointer = UnsafePointer(address)
        var slices = [UnsafeBufferPointer<UInt8>]()
        
        // How often will you exceed this?
        slices.reserveCapacity(6)
        
        var i = 0
        var length = buffer.count
        
        while length > 0 {
            pointer.peek(until: byte, length: &length, offset: &i)
            
            if pointer[-1] == byte {
                guard i > 1 else {
                    continue
                }
                
                slices.append(pointer.buffer(until: &i))
            } else {
                i = i &+ 1
                pointer = pointer.advanced(by: 1)
                slices.append(pointer.buffer(until: &i))
            }
        }
        
        return slices
    }
    
    func makeBuffer(from base: Int = 0, to end: Int? = nil) -> UnsafeBufferPointer<UInt8>? {
        let end = end ?? buffer.count
        
        guard let address = buffer.bytes, base > -1, end <= buffer.count else {
            return nil
        }
        
        return UnsafeBufferPointer<UInt8>.init(start: address.advanced(by: base), count: end &- base)
    }
    
    func makeString(from base: Int = 0, to end: Int? = nil) -> String? {
        guard let buffer = makeBuffer(from: base, to: end) else {
            return nil
        }
        
        return String(bytes: buffer, encoding: .utf8)
    }
    
    static func ==(lhs: UTF8String, rhs: UTF8String) -> Bool {
        // Same length
        guard lhs.buffer.count == rhs.buffer.count else {
            return false
        }
        
        // if they're both nil
        guard let lhsBase = lhs.buffer.bytes, let rhsBase = rhs.buffer.bytes else {
            return lhs.buffer.bytes == rhs.buffer.bytes
        }
        
        return memcmp(lhsBase, rhsBase, lhs.buffer.count) == 0
    }
    
    static func ==(lhs: UTF8String, rhs: UnsafeBufferPointer<UInt8>) -> Bool {
        guard lhs.buffer.count == rhs.count else {
            return false
        }
        
        guard let lhsBase = lhs.buffer.bytes, let base = rhs.baseAddress else {
            return lhs.buffer.bytes == nil && rhs.baseAddress == nil
        }
        
        return memcmp(lhsBase, base, rhs.count) == 0
    }
    
    private var buffer: UTF8StringBuffer
    
    init(bytes: [UInt8]) {
        self.buffer = UTF8StringBuffer(bytes)
    }
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.init(bytes: Array(buffer))
    }
    
    init() {
        self.buffer = UTF8StringBuffer()
    }
    
    init(slice: ArraySlice<UInt8>) {
        self.init(bytes: Array(slice))
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

