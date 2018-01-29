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
        let storageSize = 64
        let buffer = MutableByteBuffer(start: .allocate(capacity: storageSize), count: storageSize)
        memcpy(buffer.start, defaultHeaders.start, defaultHeadersSize)
        let view = ByteBuffer(start: buffer.baseAddress, count: defaultHeadersSize)
        return HTTPHeaderStorage(view: view, buffer: buffer, indexes: [defaultHeaderIndex])
    }

    /// Internal init for truly empty header storage.
    internal init(copying bytes: ByteBuffer, with indexes: [HTTPHeaderIndex]) {
        let buffer = MutableByteBuffer(start: .allocate(capacity: bytes.count), count: bytes.count)
        self.buffer = buffer
        memcpy(buffer.start, bytes.start, bytes.count)
        self.view = ByteBuffer(start: buffer.baseAddress, count: bytes.count)
        self.indexes = indexes
    }

    /// Create a new `HTTPHeaders` with explicit storage and indexes.
    internal init(bytes: Bytes, indexes: [HTTPHeaderIndex]) {
        let storageSize = bytes.count
        let buffer = MutableByteBuffer(start: .allocate(capacity: storageSize), count: storageSize)
        memcpy(buffer.start, bytes, storageSize)
        self.buffer = buffer
        self.view = ByteBuffer(start: buffer.baseAddress, count: storageSize)
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
        let newBuffer = MutableByteBuffer(
            start: MutableBytesPointer.allocate(capacity: buffer.count),
            count: buffer.count
        )
        memcpy(newBuffer.start, buffer.start, buffer.count)
        return HTTPHeaderStorage(
            view: ByteBuffer(start: newBuffer.start, count: view.count),
            buffer: newBuffer,
            indexes: indexes
        )
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
                    memcpy(destination, source, displacedBytes)
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

        /// if value is bigger than internal buffer, increase size
        if index.size > buffer.count - view.count {
            increaseBufferSize(by: value.count * 2) // multiply by 2 to potentially reduce realloc calls
        }

        // <name>
        memcpy(buffer.start.advanced(by: index.nameStartIndex), name.original, name.original.count)
        // `: `
        memcpy(buffer.start.advanced(by: index.nameEndIndex), headerSeparator.start, headerSeparatorSize)
        // <value>
        _ = value.withByteBuffer { valueBuffer in
            memcpy(buffer.start.advanced(by: index.valueStartIndex), valueBuffer.start, valueCount)
        }
        // `\r\n`
        memcpy(buffer.start.advanced(by: index.valueEndIndex), headerEnding.start, headerEndingSize)

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
        return indexes.flatMap { $0 }
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
        let nameData: ByteBuffer = name.lowercased.withUnsafeBufferPointer { $0 }

        for i in 0..<nameSize {
            let headerByte = headerData[i]
            let nameByte = nameData[i]

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

    /// An internal API that blindly adds a header without checking for doubles
    internal func withByteBuffer<T>(_ closure: (ByteBuffer) -> T) -> T {
        /// need room for trailing `\r\n`
        if view.count + 2 > buffer.count {
            increaseBufferSize(by: 2)
        }
        let sub = ByteBuffer(start: view.start, count: view.count + 2)
        memcpy(buffer.start.advanced(by: view.count), headerEnding.start, headerEndingSize)
        return closure(sub)
    }

    /// Increases the internal buffer size by the supplied count.
    internal func increaseBufferSize(by count: Int) {
        buffer = buffer.increaseBufferSize(by: count)
    }

    deinit {
        buffer.start.deinitialize()
        buffer.start.deallocate(capacity: buffer.count)
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
    internal mutating func increaseBufferSize(by count: Int) -> UnsafeMutableBufferPointer<Element> {
        let newSize = self.count + count
        let pointer = realloc(UnsafeMutableRawPointer(start), newSize * MemoryLayout<Element>.size)
            .assumingMemoryBound(to: Element.self)
        return .init(start: pointer, count: newSize)
    }
}

/// MARK: Static Data

private let headerSeparatorStaticString: StaticString = ": "
private let headerSeparator: ByteBuffer = headerSeparatorStaticString.withUTF8Buffer { $0 }
private let headerSeparatorSize: Int = headerSeparator.count

private let headerEndingStaticString: StaticString = "\r\n"
private let headerEnding: ByteBuffer = headerEndingStaticString.withUTF8Buffer { $0 }
private let headerEndingSize: Int = headerEnding.count

private let defaultHeadersStaticString: StaticString = "Content-Length: 0\r\n"
private let defaultHeaders: ByteBuffer = defaultHeadersStaticString.withUTF8Buffer { $0 }
private let defaultHeadersSize: Int = defaultHeaders.count
private let defaultHeaderIndex = HTTPHeaderIndex(nameStartIndex: 0, nameEndIndex: 14, valueStartIndex: 16, valueEndIndex: 17)
