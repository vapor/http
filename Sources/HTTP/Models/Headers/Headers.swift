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

public struct HeaderKey: Hashable, CustomStringConvertible {
    public let key: String
    public init(_ key: String) {
        self.key = key
    }
}

extension HeaderKey {
    public var description: String {
        return key
    }
}

extension HeaderKey: Equatable {}

extension HeaderKey {
    public var hashValue: Int {
        return key.lowercased().hashValue
    }
}

extension HeaderKey {

  //
  // Common HTTP Header Request keys
  //

  static public var Accept: HeaderKey {
    return HeaderKey("Accept")
  }

  static public var AcceptCharset: HeaderKey {
    return HeaderKey("Accept-Charset")
  }

  static public var AccepteEncoding: HeaderKey {
    return HeaderKey("Accept-Encoding")
  }

  static public var AcceptLanguage: HeaderKey {
    return HeaderKey("Accept-Language")
  }

  static public var Authorization: HeaderKey {
    return HeaderKey("Authorization")
  }

  static public var CacheControl: HeaderKey {
    return HeaderKey("Cache-Control")
  }

  static public var Connection: HeaderKey {
    return HeaderKey("Connection")
  }

  static public var Cookie: HeaderKey {
    return HeaderKey("Cookie")
  }

  static public var ContentLength: HeaderKey {
    return HeaderKey("Content-Length")
  }

  static public var ContentType: HeaderKey {
    return HeaderKey("Content-Type")
  }

  static public var Date: HeaderKey {
    return HeaderKey("Date")
  }

  static public var Expect: HeaderKey {
    return HeaderKey("Expect")
  }

  static public var Forwarded: HeaderKey {
    return HeaderKey("Forwarded")
  }

  static public var From: HeaderKey {
    return HeaderKey("From")
  }

  static public var Host: HeaderKey {
    return HeaderKey("Host")
  }

  static public var IfMatch: HeaderKey {
    return HeaderKey("If-Match")
  }

  static public var IfModifiedSince: HeaderKey {
    return HeaderKey("If-Modified-Since")
  }

  static public var IfNoneMatch: HeaderKey {
    return HeaderKey("If-None-Match")
  }

  static public var IfRange: HeaderKey {
    return HeaderKey("If-Range")
  }

  static public var IfUnmodifiedSince: HeaderKey {
    return HeaderKey("If-Unmodified-Since")
  }

  static public var MaxForwards: HeaderKey {
    return HeaderKey("Max-Forwards")
  }

  static public var Origin: HeaderKey {
    return HeaderKey("Origin")
  }

  static public var Pragma: HeaderKey {
    return HeaderKey("Pragma")
  }

  static public var ProxyAuthorization: HeaderKey {
    return HeaderKey("Proxy-Authorization")
  }

  static public var Range: HeaderKey {
    return HeaderKey("Range")
  }

  static public var Referrer: HeaderKey {
    return HeaderKey("Referer")
  }

  static public var TE: HeaderKey {
    return HeaderKey("TE")
  }

  static public var UserAgent: HeaderKey {
    return HeaderKey("User-Agent")
  }

  static public var Upgrade: HeaderKey {
    return HeaderKey("Upgrade")
  }

  static public var Via: HeaderKey {
    return HeaderKey("Via")
  }

  static public var Warning: HeaderKey {
    return HeaderKey("Warning")
  }

  //
  // Common HTTP Header Response keys
  //

  static public var AcceptPatch: HeaderKey {
    return HeaderKey("Accept-Patch")
  }

  static public var AcceptRanges: HeaderKey {
    return HeaderKey("Accept-Ranges")
  }

  static public var Age: HeaderKey {
    return HeaderKey("Age")
  }

  static public var Allow: HeaderKey {
    return HeaderKey("Allow")
  }

  static public var AlternativeServices: HeaderKey {
    return HeaderKey("Alt-Svc")
  }

  static public var ContentDisposition: HeaderKey {
    return HeaderKey("Content-Disposition")
  }

  static public var ContentEncoding: HeaderKey {
    return HeaderKey("Content-Encoding")
  }

  static public var ContentLanguage: HeaderKey {
    return HeaderKey("Content-Language")
  }

  static public var ContentLocation: HeaderKey {
    return HeaderKey("Content-Location")
  }

  static public var ContentRange: HeaderKey {
    return HeaderKey("Content-Range")
  }

  static public var Etag: HeaderKey {
    return HeaderKey("Etag")
  }

  static public var Expires: HeaderKey {
    return HeaderKey("Expires")
  }

  static public var LastModified: HeaderKey {
    return HeaderKey("Last-Modified")
  }

  static public var Link: HeaderKey {
    return HeaderKey("Link")
  }

  static public var Location: HeaderKey {
    return HeaderKey("Location")
  }

  static public var ProxyAuthenticate: HeaderKey {
    return HeaderKey("Proxy-Authenticate")
  }

  static public var PublicKeyPins: HeaderKey {
    return HeaderKey("Public-Key-Pins")
  }

  static public var RetryAfter: HeaderKey {
    return HeaderKey("Retry-After")
  }

  static public var Server: HeaderKey {
    return HeaderKey("Server")
  }

  static public var SetCookie: HeaderKey {
    return HeaderKey("Set-Cookie")
  }

  static public var StrictTransportSecurity: HeaderKey {
    return HeaderKey("Strict-Transport-Security")
  }

  static public var Trailer: HeaderKey {
    return HeaderKey("Trailer")
  }

  static public var TransferEncoding: HeaderKey {
    return HeaderKey("Transfer-Encoding")
  }

  static public var TrackingStatusValue: HeaderKey {
    return HeaderKey("TSV")
  }

  static public var Vary: HeaderKey {
    return HeaderKey("Vary")
  }

  static public var WWWAuthenticate: HeaderKey {
    return HeaderKey("WWW-Authenticate")
  }
}

public func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
    return lhs.key.lowercased() == rhs.key.lowercased()
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
