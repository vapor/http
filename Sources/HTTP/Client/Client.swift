import URI

public enum ClientProtocolError: Swift.Error {
    case missingHost
}

public protocol ClientProtocol: Program, Responder {
    var scheme: String { get }
    var stream: Stream { get }
    init(scheme: String, host: String, port: Int, securityLayer: SecurityLayer) throws
}

extension ClientProtocol {
    public init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        // default to "https" secure -- most common for clients
        try self.init(scheme: "https", host: host, port: port, securityLayer: securityLayer)
    }
}

extension ClientProtocol {
    public func request(_ method: Method, path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        // TODO: Move finish("/") to initializer
        var uri = URI(scheme: scheme, userInfo: nil, host: host, port: port, path: path.finished(with: "/"), query: nil, fragment: nil)
        uri.append(query: query)
        let request = Request(method: method, uri: uri, version: Version(major: 1, minor: 1), headers: headers, body: body)
        return try respond(to: request)
    }

    public func get(path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        return try request(.get, path: path, headers: headers, query: query, body: body)
    }

    public func post(path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        return try request(.post, path: path, headers: headers, query: query, body: body)
    }

    public func put(path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        return try request(.put, path: path, headers: headers, query: query, body: body)
    }

    public func patch(path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        return try request(.patch, path: path, headers: headers, query: query, body: body)
    }

    public func delete(_ path: String, headers: [HeaderKey: String] = [:], query: [String: CustomStringConvertible] = [:], body: Body = []) throws -> Response {
        return try request(.delete, path: path, headers: headers, query: query, body: body)
    }
}

extension ClientProtocol {
    public static func respond(to request: Request) throws -> Response {
        guard !request.uri.host.isEmpty else { throw ClientProtocolError.missingHost }
        let instance = try make(scheme: request.uri.scheme, host: request.uri.host, port: request.uri.port)
        return try instance.respond(to: request)
    }

    public static func make(scheme: String? = nil, host: String, port: Int? = nil) throws -> ClientProtocol {
        let scheme = scheme ?? "https" // default to secure https connection
        let port = port ?? URI.defaultPorts[scheme] ?? 80
        return try make(host: host, port: port, securityLayer: scheme.securityLayer)
    }

    public static func request(
        _ method: Method,
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible],
        body: Body = []
    ) throws -> Response {
        var uri = try URI(uri)
        uri.append(query: query)
        let request = Request(method: method, uri: uri, headers: headers, body: body)
        return try respond(to: request)
    }

    public static func get(
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: Body = []
    ) throws -> Response {
        return try request(.get, uri, headers: headers, query: query, body: body)
    }

    public static func post(
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: Body = []
    ) throws -> Response {
        return try request(.post, uri, headers: headers, query: query, body: body)
    }

    public static func put(
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: Body = []
    ) throws -> Response {
        return try request(.put, uri, headers: headers, query: query, body: body)
    }

    public static func patch(
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: Body = []
    ) throws -> Response {
        return try request(.patch, uri, headers: headers, query: query, body: body)
    }

    public static func delete(
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: Body = []
    ) throws -> Response {
        return try request(.delete, uri, headers: headers, query: query, body: body)
    }
}
