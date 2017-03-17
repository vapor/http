import URI
import Transport

public protocol Client: InternetStream, Responder { }

extension Client {
    public func request(
        _ method: Method,
        _ path: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: BodyRepresentable = Body.data([])
    ) throws -> Response {
        var uri = URI(
            scheme: scheme,
            hostname: hostname,
            port: port,
            path: path
        )
        uri.append(query: query)
        let body = body.makeBody()
        let request = Request(method: method, uri: uri, headers: headers, body: body)
        return try respond(to: request)
    }

    public static func respond(to request: Request) throws -> Response {
        guard !request.uri.hostname.isEmpty else {
            throw ClientError.missingHost
        }

        let instance = try Self.init(
            scheme: request.uri.scheme,
            hostname: request.uri.hostname,
            port: request.uri.port ?? 80
        )
        return try instance.respond(to: request)
    }

    public static func request(
        _ method: Method,
        _ uri: String,
        headers: [HeaderKey: String] = [:],
        query: [String: CustomStringConvertible] = [:],
        body: BodyRepresentable = Body.data([])
    ) throws -> Response {
        var uri = try URI(uri)
        uri.append(query: query)
        let body = body.makeBody()
        let request = Request(method: method, uri: uri, headers: headers, body: body)
        return try respond(to: request)
    }
}
