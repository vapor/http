import Bits
import COperatingSystem

/// COW storage for HTTP headers.
final class HTTPHeaderStorage {
    /// Valid view into the HTTPHeader's internal buffer.
    private var view: ByteBuffer

    /// The HTTPHeader's internal storage.
    private var buffer: MutableByteBuffer

    /// The HTTPHeader's known indexes into the storage.
    private var indexes: [HTTPHeaderIndex?]

    /// Creates a new `HTTPHeaders` with default content.
    static func `default`() -> HTTPHeaderStorage {
        let buffer = MutableByteBuffer.allocate(capacity: defaultHeadersSize)
        buffer.initializeAssertingNoRemainder(from: defaultHeaders)
        let view = ByteBuffer(buffer)
        return HTTPHeaderStorage(view: view, buffer: buffer, indexes: [defaultHeaderIndex])
    }

    /// Internal init for truly empty header storage.
    internal init(copying bytes: ByteBuffer, with indexes: [HTTPHeaderIndex]) {
        self.buffer = MutableByteBuffer.allocate(capacity: bytes.count)
        self.buffer.initializeAssertingNoRemainder(from: bytes)
        self.view = ByteBuffer(buffer)
        self.indexes = indexes
    }

    /// Create a new `HTTPHeaders` with explicit storage and indexes.
    internal init(bytes: Bytes, indexes: [HTTPHeaderIndex]) {
        self.buffer = MutableByteBuffer.allocate(capacity: bytes.count)
        self.buffer.initializeAssertingNoRemainder(from: bytes)
        self.view = ByteBuffer(buffer)
        self.indexes = indexes
    }

    /// Create a new `HTTPHeaders` with explicit storage and indexes.
    private init(view: ByteBuffer, buffer: MutableByteBuffer, indexes: [HTTPHeaderIndex?]) {
        self.view = view
        self.buffer = buffer
        self.indexes = indexes
    }

    /// Creates a new, identical copy of the header storage.
    internal func copy() -> HTTPHeaderStorage {
        let newBuffer = MutableByteBuffer.allocate(capacity: buffer.count)
        newBuffer.initializeAssertingNoRemainder(from: buffer)
        return .init(view: ByteBuffer(newBuffer), buffer: newBuffer, indexes: indexes)
    }

    /// Removes all headers with this name
    internal func removeValues(for name: HTTPHeaderName) {
        /// loop over all indexes
        for i in 0..<self.indexes.count {
            guard let index = indexes[i] else {
                /// skip invalidated indexes
                continue
            }

            /// check if the header at this index matches the supplied name
            if headerAt(index, matchesName: name) {
                indexes[i] = nil

                /// calculate how much valid storage data is placed
                /// after this header
                let displacedBytes = view.count - index.endIndex

                if displacedBytes > 0 {
                    /// there is valid data after this header that we must relocate
                    let destination = buffer.start.advanced(by: index.startIndex) // deleted header's start
                    let source = buffer.start.advanced(by: index.endIndex) // deleted header's end
                    
                    // Since source and destination can overlap, we have to do the Swift
                    // version of a memmove() instead of the usual equivalent memcpy().
                    _ = UnsafeMutableRawPointer(destination).moveInitializeMemory(as: Byte.self, from: source, count: displacedBytes)

                    /// fix all displaced indexes
                    for j in 0..<self.indexes.count {
                        guard let subindex = indexes[j] else {
                            /// skip invalidated indexes
                            continue
                        }

                        /// check if the subindex comes after the index
                        /// we just deleted
                        if subindex.startIndex >= index.endIndex {
                            /// update the index's offsets
                            indexes[j] = HTTPHeaderIndex(
                                nameStartIndex: subindex.nameStartIndex - index.size,
                                nameEndIndex: subindex.nameEndIndex - index.size,
                                valueStartIndex: subindex.valueStartIndex - index.size,
                                valueEndIndex: subindex.valueEndIndex - index.size
                            )
                        }
                    }
                } else {
                    // no headers after this, simply shorten the valid buffer
                }
                self.view = ByteBuffer(start: buffer.start, count: view.count - index.size)
            }
        }
    }

    /// Appends the supplied string to the header data.
    /// Note: This will naively append data, not deleting existing values. Use in
    /// conjunction with `removeValues(for:)` for that behavior.
    internal func appendValue(_ value: String, for name: HTTPHeaderName) {
        let valueCount = value.utf8.count

        /// create the new header index
        let index = HTTPHeaderIndex(
            nameStartIndex: view.count,
            nameEndIndex: view.count + name.original.count,
            valueStartIndex: view.count + name.original.count + 2,
            valueEndIndex: view.count + name.original.count + 2 + valueCount
        )
        indexes.append(index)

        /// if header is bigger than internal buffer, increase size
        if index.size > buffer.count - view.count {
            moveToLargerCopy(increasingBy: index.size * 2) // multiply by 2 to potentially reduce realloc calls
        }

        // <name>
        UnsafeMutableBufferPointer(
            start: buffer.start.advanced(by: index.nameStartIndex),
            count: name.original.count
        ).initializeAssertingNoRemainder(from: name.original)
        // `: `
        UnsafeMutableBufferPointer(
            start: buffer.start.advanced(by: index.nameEndIndex),
            count: headerSeparatorSize
        ).initializeAssertingNoRemainder(from: headerSeparator)
        // <value>
        value.withByteBuffer { valueBuffer in
            UnsafeMutableBufferPointer(
                start: buffer.start.advanced(by: index.valueStartIndex),
                count: valueCount
            ).initializeAssertingNoRemainder(from: valueBuffer)
        }
        // `\r\n`
        UnsafeMutableBufferPointer(
            start: buffer.start.advanced(by: index.valueEndIndex),
            count: headerEndingSize
        ).initializeAssertingNoRemainder(from: headerEnding)

        view = ByteBuffer(start: buffer.start, count: view.count + index.size)
    }

    /// Fetches the String value for a given header index.
    /// Use `indexes(for:)` to fetch indexes for a given header name.
    internal func value(for header: HTTPHeaderIndex) -> String? {
        return String(bytes: view[header.valueStartIndex..<header.valueEndIndex], encoding: .ascii)
    }

    /// Fetches the String name for a given header index.
    /// Use `indexes(for:)` to fetch indexes for a given header name.
    internal func name(for header: HTTPHeaderIndex) -> String? {
        return String(bytes: view[header.nameStartIndex..<header.nameEndIndex], encoding: .ascii)
    }

    /// Returns all currently-valid header indexes.
    internal func validIndexes() -> [HTTPHeaderIndex] {
        return indexes.compactMap { $0 }
    }

    /// Scans the boundary of the value associated with a name
    internal func indexes(for name: HTTPHeaderName) -> [HTTPHeaderIndex] {
        var valueRanges: [HTTPHeaderIndex] = []

        for index in indexes {
            guard let index = index else {
                continue
            }

            if headerAt(index, matchesName: name) {
                valueRanges.append(index)
            }
        }

        return valueRanges
    }


    /// Returns true if the header at the supplied index matches a given name.
    internal func headerAt(_ index: HTTPHeaderIndex, matchesName name: HTTPHeaderName) -> Bool {
        let nameSize = index.nameEndIndex - index.nameStartIndex
        guard name.lowercased.count == nameSize else {
            return false
        }

        let headerData = ByteBuffer(start: view.start.advanced(by: index.startIndex), count: index.size)
        
        return name.lowercased.withUnsafeBufferPointer {
            for i in 0..<nameSize {
                let headerByte = headerData[i]
                let nameByte = $0[i]

                /// check case that byte is exact match
                if headerByte == nameByte {
                    continue
                }

                /// check case that header data is uppercased
                if headerByte >= .A && headerByte <= .Z && headerByte &+ asciiCasingOffset == nameByte {
                    continue
                }

                return false
            }
            return true
        }
    }

    /// An internal API that blindly adds a header without checking for doubles
    internal func withByteBuffer<T>(_ closure: (ByteBuffer) -> T) -> T {
        /// need room for trailing `\r\n`
        if view.count + headerEndingSize > buffer.count {
            moveToLargerCopy(increasingBy: headerEndingSize)
        }
        MutableByteBuffer(
            start: buffer.start.advanced(by: view.count),
            count: headerEndingSize
        ).initializeAssertingNoRemainder(from: headerEnding)
        let sub = ByteBuffer(start: buffer.start, count: view.count + headerEndingSize)
        return closure(sub)
    }

    /// Increases the internal buffer size by the supplied count.
    internal func moveToLargerCopy(increasingBy count: Int) {
        buffer = buffer.moveToLargerCopy(increasingBy: count)
    }

    deinit {
        buffer.deallocate()
    }
}

extension HTTPHeaderStorage: CustomStringConvertible {
    /// See `CustomStringConvertible.description
    public var description: String {
        return debugDescription
    }
}

extension HTTPHeaderStorage: CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        return String(bytes: view, encoding: .ascii) ?? "n/a"
    }
}

/// MARK: Utility

extension UnsafeMutableBufferPointer {
    var start: UnsafeMutablePointer<Element> {
        return baseAddress!
    }
}

extension UnsafeBufferPointer {
    var start: UnsafePointer<Element> {
        return baseAddress!
    }
    
    func allocateAndInitializeCopy() -> UnsafeBufferPointer {
        let buffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: self.count)
        buffer.initializeAssertingNoRemainder(from: self)
        return UnsafeBufferPointer(buffer)
    }
}

extension String {
    func withByteBuffer<T>(_ closure: (ByteBuffer) -> T) -> T {
        let count = utf8.count
        return withCString { cPointer in
            return cPointer.withMemoryRebound(to: Byte.self, capacity: count) {
                return closure(ByteBuffer(start: $0, count: count))
            }
        }
    }
}

extension UnsafeMutableBufferPointer {
    /// Increases the mutable buffer size by the supplied count.
    internal mutating func moveToLargerCopy(increasingBy count: Int) -> UnsafeMutableBufferPointer<Element> {
        let newSize = self.count + count
        let newBuffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: newSize)
        
        newBuffer.start.moveInitialize(from: self.start, count: self.count)
        self.deallocate()
        return newBuffer
    }
}

/// MARK: Static Data

private let headerSeparatorStaticString: StaticString = ": "
private let headerSeparator: ByteBuffer = headerSeparatorStaticString.withUTF8Buffer { $0.allocateAndInitializeCopy() }
private let headerSeparatorSize: Int = headerSeparator.count

private let headerEndingStaticString: StaticString = "\r\n"
private let headerEnding: ByteBuffer = headerEndingStaticString.withUTF8Buffer { $0.allocateAndInitializeCopy() }
private let headerEndingSize: Int = headerEnding.count

private let defaultHeadersStaticString: StaticString = "Content-Length: 0\r\n"
private let defaultHeaders: ByteBuffer = defaultHeadersStaticString.withUTF8Buffer { $0.allocateAndInitializeCopy() }
private let defaultHeadersSize: Int = defaultHeaders.count
private let defaultHeaderIndex = HTTPHeaderIndex(nameStartIndex: 0, nameEndIndex: 14, valueStartIndex: 16, valueEndIndex: 17)
