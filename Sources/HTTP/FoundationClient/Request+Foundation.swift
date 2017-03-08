import URI
import Foundation

extension Request {
    func makeFoundationRequest() throws -> URLRequest {
        let url = try uri.makeFoundationURL()
        var request = URLRequest(url: url)
        request.httpMethod = method.description.uppercased()
        request.httpBody = body.bytes.flatMap { Data(bytes: $0) }
        headers.forEach { key, val in
            request.addValue(val, forHTTPHeaderField: key.description)
        }
        return request
    }
}

extension URLRequest {
    enum ConversionError: Error {
        case missingURI
        case missingMethod
    }

    func makeRequest() throws -> Request {
        guard let url = url else { throw ConversionError.missingURI }
        let uri = url.makeURI()
        guard let httpMethod = httpMethod else { throw ConversionError.missingMethod }
        let method = Method(uppercased: httpMethod.makeBytes())
        let bytes = httpBody?.makeBytes()

        var headers: [HeaderKey: String] = [:]
        allHTTPHeaderFields?.forEach { key, value in
            headers[key] = value
        }

        let body = bytes.flatMap { Body($0) } ?? Body([])
        return Request(method: method, uri: uri, headers: headers, body: body)
    }
}
