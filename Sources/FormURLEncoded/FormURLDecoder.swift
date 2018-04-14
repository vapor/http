import Core
import HTTP

/// Decodes instances of `Decodable` types from `Data`.
///
///     print(data) /// Data
///     let user = try FormURLDecoder().decode(User.self, from: data)
///     print(user) /// User
///
public final class FormURLDecoder: DataDecoder, HTTPMessageDecoder {
    /// The underlying `FormURLEncodedParser`
    private let parser: FormURLEncodedParser

    /// If `true`, empty values will be omitted. Empty values are URL-Encoded keys with no value following the `=` sign.
    public var omitEmptyValues: Bool

    /// If `true`, flags will be omitted. Flags are URL-encoded keys with no following `=` sign.
    public var omitFlags: Bool

    /// Create a new `FormURLDecoder`.
    ///
    /// - parameters:
    ///     - omitEmptyValues: If `true`, empty values will be omitted.
    ///                        Empty values are URL-Encoded keys with no value following the `=` sign.
    ///     - omitFlags: If `true`, flags will be omitted.
    ///                  Flags are URL-encoded keys with no following `=` sign.
    public init(omitEmptyValues: Bool = false, omitFlags: Bool = false) {
        self.parser = FormURLEncodedParser()
        self.omitFlags = omitFlags
        self.omitEmptyValues = omitEmptyValues
    }

    /// Decodes an instance of the supplied `Decodable` type from `Data`.
    ///
    ///     print(data) /// Data
    ///     let user = try FormURLDecoder().decode(User.self, from: data)
    ///     print(user) /// User
    ///
    /// - parameters:
    ///     - decodable: Generic `Decodable` type (`D`) to decode.
    ///     - from: `Data` to decode a `D` from.
    /// - returns: An instance of the `Decodable` type (`D`).
    /// - throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D>(_ decodable: D.Type, from data: Data) throws -> D where D : Decodable {
        let formURLData = try self.parser.parse(percentEncoded: String(data: data, encoding: .utf8) ?? "", omitEmptyValues: self.omitEmptyValues, omitFlags: self.omitFlags)
        let decoder = _FormURLDecoder(data: .dictionary(formURLData), codingPath: [])
        return try D(from: decoder)
    }

    /// Decodes the supplied `Decodable` type from an `HTTPBody`.
    ///
    ///     let decoder: BodyDecoder = FormURLDecoder()
    ///     let string = try decoder.decode(String.self, from: HTTPBody(string: "hello"), on: ...).wait()
    ///     print(string) /// "hello" from the HTTP body
    ///
    /// - parameters:
    ///     - decodable: `Decodable` type to decode from the `HTTPBody`.
    ///     - from: `HTTPBody` to decode the `Decodable` type from. This `HTTPBody` may be static or streaming.
    ///     - maxSize: Maximum size in bytes for streaming bodies.
    ///     - on: `Worker` to perform asynchronous tasks on.
    /// - returns: `Future` containing the decoded type.
    /// - throws: Any errors that may have occurred while decoding the `HTTPBody`.
    public func decode<D, M>(_ type: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
    {
        guard message.mediaType == .urlEncodedForm else {
            throw HTTPError(identifier: "contentType", reason: "HTTP message did not have form-urlencoded content-type.", source: .capture())
        }
        return message.body.consumeData(max: maxSize, on: worker).map(to: D.self) { data in
            return try self.decode(D.self, from: data)
        }
    }
}

/// MARK: Private

/// Internal form urlencoded decoder.
/// See FormURLDecoder for the public decoder.
final class _FormURLDecoder: Decoder {
    /// See Decoder.codingPath
    let codingPath: [CodingKey]

    /// See Decoder.userInfo
    let userInfo: [CodingUserInfoKey: Any]

    /// The data being decoded
    let data: FormURLEncodedData

    /// Creates a new form urlencoded decoder
    init(data: FormURLEncodedData, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
        self.userInfo = [:]
    }

    /// See Decoder.container
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey
    {
        let container = FormURLKeyedDecoder<Key>(data: data, codingPath: codingPath)
        return .init(container)
    }

    /// See Decoder.unkeyedContainer
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return FormURLUnkeyedDecoder(data: data, codingPath: codingPath)
    }

    /// See Decoder.singleValueContainer
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return FormURLSingleValueDecoder(data: data, codingPath: codingPath)
    }
}

extension DecodingError {
    public static func typeMismatch(_ type: Any.Type, atPath path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at path \(pathString)"
        )
        return Swift.DecodingError.typeMismatch(type, context)
    }
}
