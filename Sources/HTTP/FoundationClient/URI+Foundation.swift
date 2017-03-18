import URI
import Foundation

extension URI {
    public enum ConversionError: Error {
        case unableToMakeFoundationURL
    }

    public func makeFoundationURL() throws -> URL {
        var comps = URLComponents()
        comps.scheme = scheme.isEmpty ? nil : scheme
        comps.user = userInfo?.username
        comps.password = userInfo?.info
        comps.host = hostname.isEmpty ? nil : hostname
        comps.port = port.flatMap(Int.init)
        comps.path = path
        comps.query = query
        comps.fragment = fragment
        guard let url = comps.url else { throw ConversionError.unableToMakeFoundationURL }
        return url
    }
}

extension URL {
    public func makeURI() -> URI {
        let userInfo: URI.UserInfo? = user.flatMap {
            URI.UserInfo(username: $0, info: password)
        }
        return URI(
            scheme: scheme ?? "",
            userInfo: userInfo,
            hostname: host ?? "",
            port: port?.port,
            path: path,
            query: query,
            fragment: fragment
        )
    }
}
