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
        case field
        case value(field: String)
    }
    
    private var headerState: HeaderState
    private var currentHeaders: [String: String]
    private var currentData: String
    private var hasInitialized: Bool
    
    /// Creates a new `MultipartParser`.
    public init(boundary: String) {
        self.onPart = { _ in }
        var parser = multipartparser()
        multipartparser_init(&parser, boundary)
        var callbacks = multipartparser_callbacks()
        multipartparser_callbacks_init(&callbacks)
        self.callbacks = callbacks
        self.parser = parser
        self.headerState = .field
        self.currentHeaders = [:]
        self.currentData = ""
        self.hasInitialized = false
    }

    public func execute(_ data: String) throws {
        if !self.hasInitialized {
            self.initialize()
            self.hasInitialized = true
        }
        #warning("TODO: how to do c baton in swift?")
        withUnsafePointer(to: self, { pointer in
            self.parser.data = UnsafeMutableRawPointer(mutating: pointer)
        })
        multipartparser_execute(&self.parser, &self.callbacks, data, data.utf8.count)
    }
    
    private func initialize() {
        self.callbacks.on_header_field = { parser, data, size in
            let string = String(cPointer: data, count: size)
            parser!.pointee.data.assumingMemoryBound(to: MultipartParser.self).pointee.handleHeaderField(string)
            return 0
        }
        self.callbacks.on_header_value = { parser, data, size in
            let string = String(cPointer: data, count: size)
            parser!.pointee.data.assumingMemoryBound(to: MultipartParser.self).pointee.handleHeaderValue(string)
            return 0
        }
        self.callbacks.on_data = { parser, data, size in
            let string = String(cPointer: data, count: size)
            parser!.pointee.data.assumingMemoryBound(to: MultipartParser.self).pointee.handleData(string)
            return 0
        }
        self.callbacks.on_body_begin = { parser in
            return 0
        }
        self.callbacks.on_headers_complete = { parser in
            return 0
        }
        self.callbacks.on_part_end = { parser in
            parser!.pointee.data.assumingMemoryBound(to: MultipartParser.self).pointee.handlePartEnd()
            return 0
        }
        self.callbacks.on_body_end = { parser in
            return 0
        }
    }
    
    private func handleHeaderField(_ name: String) {
        switch self.headerState {
        case .field:
            self.headerState = .value(field: name)
        default: fatalError()
        }
    }
    
    private func handleHeaderValue(_ value: String) {
        switch self.headerState {
        case .value(let field):
            self.headerState = .field
            self.currentHeaders[field] = value
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

private extension String {
    init(cPointer: UnsafePointer<Int8>?, count: Int) {
        let pointer = UnsafeRawPointer(cPointer)?.assumingMemoryBound(to: UInt8.self)
        self.init(decoding: UnsafeBufferPointer(start: pointer, count: count), as: UTF8.self)
    }
}
