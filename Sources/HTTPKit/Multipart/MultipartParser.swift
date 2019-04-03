import CMultipartParser

/// Parses multipart-encoded `Data` into `MultipartPart`s. Multipart encoding is a widely-used format for encoding/// web-form data that includes rich content like files. It allows for arbitrary data to be encoded
/// in each part thanks to a unique delimiter "boundary" that is defined separately. This
/// boundary is guaranteed by the client to not appear anywhere in the data.
///
/// `multipart/form-data` is a special case of `multipart` encoding where each part contains a `Content-Disposition`
/// header and name. This is used by the `FormDataEncoder` and `FormDataDecoder` to convert `Codable` types to/from
/// multipart data.
///
/// See [Wikipedia](https://en.wikipedia.org/wiki/MIME#Multipart_messages) for more information.
///
/// Seealso `form-urlencoded` encoding where delimiter boundaries are not required.
public final class MultipartParser {
    public var onPart: (MultipartPart) -> ()
    
    private var callbacks: multipartparser_callbacks
    private var parser: multipartparser
    
    private enum HeaderState {
        case ready
        case field(field: String)
        case value(field: String, value: String)
    }
    
    private var headerState: HeaderState
    
    private var currentHeaders: [String: String]
    private var currentData: String
    
    /// Creates a new `MultipartParser`.
    public init(boundary: String) {
        self.onPart = { _ in }
        var parser = multipartparser()
        multipartparser_init(&parser, boundary)
        var callbacks = multipartparser_callbacks()
        multipartparser_callbacks_init(&callbacks)
        self.callbacks = callbacks
        self.parser = parser
        self.headerState = .ready
        self.currentHeaders = [:]
        self.currentData = ""
        self.callbacks.on_header_field = { parser, data, size in
            guard let parser = parser else {
                return 1
            }
            let string = String(cPointer: data, count: size)
            parser.ref.handleHeaderField(string)
            return 0
        }
        self.callbacks.on_header_value = { parser, data, size in
            guard let parser = parser else {
                return 1
            }
            let string = String(cPointer: data, count: size)
            parser.ref.handleHeaderValue(string)
            return 0
        }
        self.callbacks.on_data = { parser, data, size in
            guard let parser = parser else {
                return 1
            }
            let string = String(cPointer: data, count: size)
            parser.ref.handleData(string)
            return 0
        }
        self.callbacks.on_body_begin = { parser in
            return 0
        }
        self.callbacks.on_headers_complete = { parser in
            guard let parser = parser else {
                return 1
            }
            parser.ref.handleHeadersComplete()
            return 0
        }
        self.callbacks.on_part_end = { parser in
            guard let parser = parser else {
                return 1
            }
            parser.ref.handlePartEnd()
            return 0
        }
        self.callbacks.on_body_end = { parser in
            return 0
        }
    }

    public func execute(_ data: String) throws {
        withUnsafePointer(to: self, { pointer in
            self.parser.data = UnsafeMutableRawPointer(mutating: pointer)
            multipartparser_execute(&self.parser, &self.callbacks, data, data.utf8.count)
        })
    }
    
    // MARK: Private
    
    private func handleHeaderField(_ new: String) {
        switch self.headerState {
        case .ready:
            self.headerState = .field(field: new)
        case .field(let existing):
            self.headerState = .field(field: existing + new)
        case .value(let field, let value):
            self.currentHeaders[field] = value
            self.headerState = .field(field: new)
        }
    }
    
    private func handleHeaderValue(_ new: String) {
        switch self.headerState {
        case .field(let name):
            self.headerState = .value(field: name, value: new)
        case .value(let name, let existing):
            self.headerState = .value(field: name, value: existing + new)
        default: fatalError()
        }
    }
    
    private func handleHeadersComplete() {
        switch self.headerState {
        case .value(let field, let value):
            self.currentHeaders[field] = value
            self.headerState = .ready
        case .ready: break
        default: fatalError()
        }
    }
    
    private func handleData(_ data: String) {
        self.currentData += data
    }
    
    private func handlePartEnd() {
        let part = MultipartPart(data: self.currentData, headers: self.currentHeaders)
        self.currentData = ""
        self.currentHeaders = [:]
        self.onPart(part)
    }
}

private extension  UnsafeMutablePointer where Pointee == multipartparser {
    var ref: MultipartParser {
        return self.pointee.data.assumingMemoryBound(to: MultipartParser.self).pointee
    }
}

private extension String {
    init(cPointer: UnsafePointer<Int8>?, count: Int) {
        let pointer = UnsafeRawPointer(cPointer)?.assumingMemoryBound(to: UInt8.self)
        self.init(decoding: UnsafeBufferPointer(start: pointer, count: count), as: UTF8.self)
    }
}
