import struct Foundation.Data

/// Supports converting to / from a `MultipartPart`.
public protocol MultipartPartConvertible {
    /// Converts `self` to `MultipartPart`.
    func convertToMultipartPart() throws -> MultipartPart

    /// Converts a `MultipartPart` to `Self`.
    static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self
}

extension MultipartPart: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart { return self }
    
    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> MultipartPart { return part }
}

extension String: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: self)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> String {
        return part.data
    }
}

extension FixedWidthInteger {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description, headers: [:])
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self {
        guard let fwi = Self(part.data) else {
            throw MultipartError(identifier: "int", reason: "Could not convert `Data` to `\(Self.self)`.")
        }
        return fwi
    }
}

extension Int: MultipartPartConvertible { }
extension Int8: MultipartPartConvertible { }
extension Int16: MultipartPartConvertible { }
extension Int32: MultipartPartConvertible { }
extension Int64: MultipartPartConvertible { }
extension UInt: MultipartPartConvertible { }
extension UInt8: MultipartPartConvertible { }
extension UInt16: MultipartPartConvertible { }
extension UInt32: MultipartPartConvertible { }
extension UInt64: MultipartPartConvertible { }


extension Float: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Float {
        guard let float = Float(part.data) else {
            throw MultipartError(identifier: "float", reason: "Could not convert `Data` to `\(Float.self)`.")
        }
        return float
    }
}

extension Double: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Double {
        guard let double = Double(part.data) else {
            throw MultipartError(identifier: "double", reason: "Could not convert `Data` to `\(Double.self)`.")
        }
        return double
    }
}

extension Bool: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Bool {
        guard let option = Bool(part.data) else {
            throw MultipartError(identifier: "boolean", reason: "Could not convert `Data` to `Bool`. Must be one of: [true, false]")
        }
        return option
    }
}

extension HTTPFile: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        var part = MultipartPart(data: data)
        part.filename = filename
        part.contentType = contentType
        return part
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> HTTPFile {
        guard let filename = part.filename else {
            throw MultipartError(identifier: "filename", reason: "Multipart part missing a filename.")
        }
        return HTTPFile(data: part.data, filename: filename)
    }
}

extension Data: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: String(decoding: self, as: UTF8.self))
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Data {
        return Data(part.data.utf8)
    }
}
