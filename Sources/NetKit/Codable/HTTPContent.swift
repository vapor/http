/// Convertible to / from content in an HTTP message.
///
/// If adding conformance in an extension, you must ensure the type already exists to `Codable`.
///
///     struct Hello: Content {
///         let message = "Hello!"
///     }
///
///     router.get("greeting") { req in
///         return Hello() // {"message":"Hello!"}
///     }
///
public protocol HTTPContent: Codable {
    /// The default `MediaType` to use when _encoding_ content. This can always be overridden at the encode call.
    ///
    /// Default implementation is `MediaType.json` for all types.
    ///
    ///     struct Hello: Content {
    ///         static let defaultContentType = .urlEncodedForm
    ///         let message = "Hello!"
    ///     }
    ///
    ///     router.get("greeting") { req in
    ///         return Hello() // message=Hello!
    ///     }
    ///
    ///     router.get("greeting2") { req in
    ///         let res = req.response()
    ///         try res.content.encode(Hello(), as: .json)
    ///         return res // {"message":"Hello!"}
    ///     }
    ///
    static var defaultContentType: HTTPMediaType { get }
}

/// MARK: Default Implementations

extension HTTPContent {
    /// Default implementation is `MediaType.json` for all types.
    ///
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}

// MARK: Default Conformances

extension String: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int8: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int16: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int32: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Int64: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt8: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt16: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt32: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension UInt64: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Double: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Float: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .plainText
    }
}

extension Array: HTTPContent where Element: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}

extension Dictionary: HTTPContent where Key == String, Value: HTTPContent {
    /// See `Content`.
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}
