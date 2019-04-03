/// Represents a single file.
public struct HTTPFile: Codable {
    /// Name of the file, including extension.
    public var filename: String
    
    /// The file's data.
    public var data: [UInt8]
    
    /// Associated `MediaType` for this file's extension, if it has one.
    public var contentType: HTTPMediaType? {
        return ext.flatMap { HTTPMediaType.fileExtension($0.lowercased()) }
    }
    
    /// The file extension, if it has one.
    public var ext: String? {
        return filename.split(separator: ".").last.map(String.init)
    }
    
    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: String, filename: String) {
        self.init(data: [UInt8](data.utf8), filename: filename)
    }
    
    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: [UInt8], filename: String) {
        self.data = data
        self.filename = filename
    }
}
