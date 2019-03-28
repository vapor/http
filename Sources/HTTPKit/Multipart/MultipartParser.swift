/// Parses multipart-encoded `Data` into `MultipartPart`s. Multipart encoding is a widely-used format for encoding
/// web-form data that includes rich content like files. It allows for arbitrary data to be encoded
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
    /// Creates a new `MultipartParser`.
    public init() { }

    /// Parses `Data` into a `MultipartForm` according to the supplied boundary.
    ///
    ///     // Content-Type: multipart/form-data; boundary=123
    ///     let data = """
    ///     --123\r
    ///     \r
    ///     foo\r
    ///     --123--\r
    ///
    ///     """
    ///     let form = try MultipartParser().parse(data: data, boundary: "123")
    ///     print(form.parts.count) // 1
    ///
    /// - parameters:
    ///     - data: `multipart` encoded data to parse.
    ///     - boundary: Multipart boundary separating the parts.
    /// - throws: Any errors parsing the encoded data.
    /// - returns: `MultipartForm` containing the parsed `MultipartPart`s.
    public func parse(data: String, boundary: String) throws -> [MultipartPart] {
        return try _MultipartParser(data: data, boundary: boundary).parse()
    }
}

// MARK: Private

/// Internal parser implementation.
/// TODO: Move to more performant impl, such as `ByteBuffer`.
private final class _MultipartParser {
    /// The boundary between all parts
    private let boundary: String
    
    /// A helper variable that consists of all bytes inbetween one part's body and the next part's headers
    private let fullBoundary: String
    
    /// The multipart form data to parse
    private let data: String
    
    /// The current position, used for parsing
    private var position: String.Index
    
    /// The output form
    private var parts: [MultipartPart]
    
    /// Creates a new parser for a Multipart form
    init(data: String, boundary: String) {
        self.data = data
        self.position = data.startIndex
        self.boundary = boundary
        self.parts = []
        self.fullBoundary = "\r\n--" + self.boundary
    }


    /// Parses the `Data` and adds it to the Multipart.
    func parse() throws -> [MultipartPart] {
        guard parts.count == 0 else {
            throw MultipartError(identifier: "multipart:multiple-parses", reason: "Multipart may only be parsed once")
        }
        
        while self.position <= self.data.endIndex {
            // require '--' + boundary + \r\n
            try self.require(self.fullBoundary.count)
            
            // assert '--'
            try self.assertBoundaryStartEnd()
            
            // skip '--'
            self.position = self.data.index(self.position, offsetBy: 2)
            
            let matches = self.data[self.position..<self.data.index(self.position, offsetBy: self.boundary.count)] == self.boundary
            
            // check boundary
            guard matches else {
                throw MultipartError(identifier: "boundary", reason: "Wrong boundary")
            }
            
            // skip boundary
            self.position = self.data.index(self.position, offsetBy: boundary.count)
            guard try self.carriageReturnNewLine() else {
                try self.assertBoundaryStartEnd()
                return self.parts
            }
            
            let headers = try self.readHeaders()
            try self.appendPart(headers: headers)
            
            // If it doesn't end in a second `\r\n`, this must be the end of the data z
            guard try self.carriageReturnNewLine() else {
                guard data[self.position..<self.data.index(self.position, offsetBy: 2)] == "--" else {
                    throw MultipartError(identifier: "eof", reason: "Invalid multipart ending")
                }
                
                return parts
            }
            
            // skip '\r\n'
            self.position = self.data.index(self.position, offsetBy: 1)
        }
        
        return parts
    }
    /// Asserts that the position is on top of two hyphens
    private func assertBoundaryStartEnd() throws {
        guard self.data[self.position..<self.data.index(self.position, offsetBy: 2)] == "--" else {
            throw MultipartError(identifier: "boundary", reason: "Invalid multipart formatting")
        }
    }

    /// Reads the headers at the current position
    private func readHeaders() throws -> [String: String] {
        var headers: [String: String] = [:]

        // headers
        headerScan: while position <= self.data.endIndex, try self.carriageReturnNewLine() {
            // skip \r\n
            self.position = self.data.index(self.position, offsetBy: 1)

            // `\r\n\r\n` marks the end of headers
            if try self.carriageReturnNewLine() {
                self.position = self.data.index(self.position, offsetBy: 1)
                break headerScan
            }

            // header key
            guard let key = try self.scanStringUntil(":") else {
                throw MultipartError(identifier: "multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
            }

            // skip space (': ')
            self.position = self.data.index(self.position, offsetBy: 2)

            // header value
            guard let value = try self.scanStringUntil("\r\n") else {
                throw MultipartError(identifier: "multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
            }

            headers[String(key)] = String(value)
        }

        return headers
    }

    /// Parses the part data until the boundary and decodes it.
    ///
    /// Also appends the part to the Multipart
    private func appendPart(headers: [String: String]) throws {
        // The compiler doesn't understand this will never be `nil`
        let partData = try self.seekUntilBoundary()

        let part = MultipartPart(data: String(partData), headers: headers)
        self.parts.append(part)
    }


    /// Parses the part data until the boundary
    private func seekUntilBoundary() throws -> Substring {
        var base = self.position

        // Seeks to the end of this part's content
        contentSeek: while true {
            try require(self.fullBoundary.count)

            #warning("TODO: more optimized check")
            let matches = self.data[base..<self.data.index(base, offsetBy: fullBoundary.count)] == fullBoundary
            if matches {
                break contentSeek
            }
            base = self.data.index(base, offsetBy: 1)
        }
        
        defer { self.position = base }
        return self.data[self.position..<base]
    }

    // Scans until the trigger is found
    // Instantiates a String from the found data
    private func scanStringUntil(_ trigger: Character) throws -> Substring? {
        var offset = 0
        headerKey: while true {
            guard self.data.index(self.position, offsetBy: offset) < self.data.endIndex else {
                throw MultipartError(identifier: "multipart:eof", reason: "Unexpected end of multipart")
            }
            if self.data[self.data.index(self.position, offsetBy: offset)] == trigger {
                break headerKey
            }

            offset += 1
        }

        defer {
            self.position = self.data.index(self.position, offsetBy: offset)
        }
        return data[self.position..<self.data.index(self.position, offsetBy: offset)]
    }

    // Checks if the current position contains a `\r\n`
    private func carriageReturnNewLine() throws -> Bool {
        try self.require(1)
        return self.data[self.position] == "\r\n"
    }

    // Requires `n` bytes
    private func require(_ n: Int) throws {
        guard self.data.index(self.position, offsetBy: n) < self.data.endIndex else {
            throw MultipartError(identifier: "missingData", reason: "Invalid multipart formatting")
        }
    }
}
