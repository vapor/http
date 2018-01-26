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

    /// Creates a new, empty `HTTPHeaders`.
    public init() {
        let storageSize = 1024
        let buffer = MutableByteBuffer(start: .allocate(capacity: storageSize), count: storageSize)
        memcpy(buffer.baseAddress, defaultHeaders.baseAddress!, defaultHeadersSize)
        self.buffer = buffer
        self.view = ByteBuffer(start: buffer.baseAddress, count: defaultHeadersSize)
        self.indexes = []
    }

    /// Create a new `HTTPHeaders` with explicit storage and indexes.
    internal init(bytes: Bytes, indexes: [HTTPHeaderIndex]) {
        let storageSize = view.count
        let buffer = MutableByteBuffer(start: .allocate(capacity: storageSize), count: storageSize)
        memcpy(buffer.baseAddress, bytes, storageSize)
        self.buffer = buffer
        self.view = ByteBuffer(start: buffer.baseAddress, count: storageSize)
        self.indexes = indexes
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
                let displacedBytes = view.count - index.startIndex

                if displacedBytes > 0 {
                    /// there is valid data after this header that we must relocate
                    let destination = buffer.start.advanced(by: index.startIndex) // deleted header's start
                    let source = buffer.start.advanced(by: index.endIndex) // deleted header's end
                    memcpy(destination, source, displacedBytes)
                } else {
                    // no headers after this, simply shorten the valid buffer
                    self.view = ByteBuffer(start: buffer.start, count: view.count - index.size)
                }
            }
        }
    }

    /// Appends the supplied string to the header data.
    /// Note: This will naively append data, not deleting existing values. Use in
    /// conjunction with `removeValues(for:)` for that behavior.
    internal func appendValue(_ value: String, for name: HTTPHeaderName) {
        let value = value.buffer

        /// create the new header index
        let index = HTTPHeaderIndex(
            nameStartIndex: view.count,
            nameEndIndex: view.count + name.lowercased.count,
            valueStartIndex: view.count + name.lowercased.count + 2,
            valueEndIndex: view.count + name.lowercased.count + 2 + value.count
        )
        indexes.append(index)

        /// if value is bigger than internal buffer, increase size
        if index.size > buffer.count - view.count {
            increaseBufferSize(by: value.count * 2) // multiply by 2 to potentially reduce realloc calls
        }

        // <name>
        memcpy(buffer.start.advanced(by: index.nameStartIndex), name.lowercased, name.lowercased.count)
        // `: `
        memcpy(buffer.start.advanced(by: index.nameEndIndex), headerSeparator.start, headerSeparatorSize)
        // <value>
        memcpy(buffer.start.advanced(by: index.valueStartIndex), value.start, value.count)
        // `\r\n`
        memcpy(buffer.start.advanced(by: index.valueEndIndex), headerEnding.start, headerEndingSize)

        view = ByteBuffer(start: buffer.start, count: view.count + index.endIndex)
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

        let nameData: ByteBuffer = name.lowercased.withUnsafeBufferPointer { $0 }

        for i in 0..<nameSize {
            let headerByte = view[i]
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
        let newSize = buffer.count + count
        let pointer: MutableBytesPointer = realloc(UnsafeMutableRawPointer(buffer.start), newSize)
            .assumingMemoryBound(to: Byte.self)
        buffer = MutableByteBuffer(start: pointer, count: newSize)
    }
}

extension HTTPHeaderStorage: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
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
    var buffer: ByteBuffer {
        let count = utf8.count
        return withCString { cPointer in
            return ByteBuffer(start: cPointer.withMemoryRebound(to: Byte.self, capacity: count) { $0 }, count: count)
        }
    }
}

/// MARK: Static Data

private let headerSeparatorStaticString: StaticString = ": "
private let headerSeparator: ByteBuffer = headerSeparatorStaticString.withUTF8Buffer { $0 }
private let headerSeparatorSize: Int = headerSeparator.count

private let headerEndingStaticString: StaticString = "\r\n"
private let headerEnding: ByteBuffer = headerEndingStaticString.withUTF8Buffer { $0 }
private let headerEndingSize: Int = headerEnding.count

private let defaultHeadersStaticString: StaticString = "Content-Length: 0\r\n\r\n"
private let defaultHeaders: ByteBuffer = defaultHeadersStaticString.withUTF8Buffer { $0 }
private let defaultHeadersSize: Int = defaultHeaders.count
