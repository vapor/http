// TODO: => Core

public protocol KeyAccessible {
    associatedtype Key
    associatedtype Value
    subscript(key: Key) -> Value? { get set }
}

extension Dictionary: KeyAccessible {}

extension KeyAccessible where Key == HeaderKey, Value == String {
    subscript(str: String) -> Value? {
        get {
            return self[HeaderKey(str)]
        }
        set {
            self[HeaderKey(str)] = newValue
        }
    }
}

// TODO: => Core ^

public struct HeaderKey {
    public let key: String
    public init(_ key: String) {
        self.key = key
    }
}

extension HeaderKey: CustomStringConvertible {
    public var description: String {
        return key
    }
}

extension HeaderKey: Hashable {
    public var hashValue: Int {
        return key.lowercased().hashValue
    }

    static public func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
        return lhs.key.lowercased() == rhs.key.lowercased()
    }
}

extension HeaderKey {

  //
  // Common HTTP Header Request keys
  //

  static public var accept: HeaderKey {
    return HeaderKey("Accept")
  }

  static public var acceptCharset: HeaderKey {
    return HeaderKey("Accept-Charset")
  }

  static public var acceptEncoding: HeaderKey {
    return HeaderKey("Accept-Encoding")
  }

  static public var acceptLanguage: HeaderKey {
    return HeaderKey("Accept-Language")
  }

  static public var authorization: HeaderKey {
    return HeaderKey("Authorization")
  }

  static public var cacheControl: HeaderKey {
    return HeaderKey("Cache-Control")
  }

  static public var connection: HeaderKey {
    return HeaderKey("Connection")
  }

  static public var cookie: HeaderKey {
    return HeaderKey("Cookie")
  }

  static public var contentLength: HeaderKey {
    return HeaderKey("Content-Length")
  }

  static public var contentType: HeaderKey {
    return HeaderKey("Content-Type")
  }

  static public var date: HeaderKey {
    return HeaderKey("Date")
  }

  static public var expect: HeaderKey {
    return HeaderKey("Expect")
  }

  static public var forwarded: HeaderKey {
    return HeaderKey("Forwarded")
  }

  static public var from: HeaderKey {
    return HeaderKey("From")
  }

  static public var host: HeaderKey {
    return HeaderKey("Host")
  }

  static public var ifMatch: HeaderKey {
    return HeaderKey("If-Match")
  }

  static public var ifModifiedSince: HeaderKey {
    return HeaderKey("If-Modified-Since")
  }

  static public var ifNoneMatch: HeaderKey {
    return HeaderKey("If-None-Match")
  }

  static public var ifRange: HeaderKey {
    return HeaderKey("If-Range")
  }

  static public var ifUnmodifiedSince: HeaderKey {
    return HeaderKey("If-Unmodified-Since")
  }

  static public var maxForwards: HeaderKey {
    return HeaderKey("Max-Forwards")
  }

  static public var origin: HeaderKey {
    return HeaderKey("Origin")
  }

  static public var pragma: HeaderKey {
    return HeaderKey("Pragma")
  }

  static public var proxyAuthorization: HeaderKey {
    return HeaderKey("Proxy-Authorization")
  }

  static public var range: HeaderKey {
    return HeaderKey("Range")
  }

  static public var referrer: HeaderKey {
    return HeaderKey("Referer")
  }

  static public var transferCodingExceptions: HeaderKey {
    return HeaderKey("TE")
  }

  static public var userAgent: HeaderKey {
    return HeaderKey("User-Agent")
  }

  static public var upgrade: HeaderKey {
    return HeaderKey("Upgrade")
  }

  static public var via: HeaderKey {
    return HeaderKey("Via")
  }

  static public var warning: HeaderKey {
    return HeaderKey("Warning")
  }

  //
  // Common HTTP Header Response keys
  //

  static public var acceptPatch: HeaderKey {
    return HeaderKey("Accept-Patch")
  }

  static public var acceptRanges: HeaderKey {
    return HeaderKey("Accept-Ranges")
  }

  static public var age: HeaderKey {
    return HeaderKey("Age")
  }

  static public var allow: HeaderKey {
    return HeaderKey("Allow")
  }

  static public var alternativeServices: HeaderKey {
    return HeaderKey("Alt-Svc")
  }

  static public var contentDisposition: HeaderKey {
    return HeaderKey("Content-Disposition")
  }

  static public var contentEncoding: HeaderKey {
    return HeaderKey("Content-Encoding")
  }

  static public var contentLanguage: HeaderKey {
    return HeaderKey("Content-Language")
  }

  static public var contentLocation: HeaderKey {
    return HeaderKey("Content-Location")
  }

  static public var contentRange: HeaderKey {
    return HeaderKey("Content-Range")
  }

  static public var etag: HeaderKey {
    return HeaderKey("Etag")
  }

  static public var expires: HeaderKey {
    return HeaderKey("Expires")
  }

  static public var lastModified: HeaderKey {
    return HeaderKey("Last-Modified")
  }

  static public var link: HeaderKey {
    return HeaderKey("Link")
  }

  static public var location: HeaderKey {
    return HeaderKey("Location")
  }

  static public var proxyAuthenticate: HeaderKey {
    return HeaderKey("Proxy-Authenticate")
  }

  static public var publicKeyPins: HeaderKey {
    return HeaderKey("Public-Key-Pins")
  }

  static public var retryAfter: HeaderKey {
    return HeaderKey("Retry-After")
  }

  static public var server: HeaderKey {
    return HeaderKey("Server")
  }

  static public var setCookie: HeaderKey {
    return HeaderKey("Set-Cookie")
  }

  static public var strictTransportSecurity: HeaderKey {
    return HeaderKey("Strict-Transport-Security")
  }

  static public var trailer: HeaderKey {
    return HeaderKey("Trailer")
  }

  static public var transferEncoding: HeaderKey {
    return HeaderKey("Transfer-Encoding")
  }

  static public var trackingStatusValue: HeaderKey {
    return HeaderKey("TSV")
  }

  static public var vary: HeaderKey {
    return HeaderKey("Vary")
  }

  static public var wwwAuthenticate: HeaderKey {
    return HeaderKey("WWW-Authenticate")
  }
}

extension HeaderKey: ExpressibleByStringLiteral {
    public init(stringLiteral string: String) {
        self.init(string)
    }

    public init(extendedGraphemeClusterLiteral string: String){
        self.init(string)
    }

    public init(unicodeScalarLiteral string: String){
        self.init(string)
    }
}
