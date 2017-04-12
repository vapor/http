import Core
import Foundation

extension URI {
    /**
        Returns the components of a given path, ignoring a trailing slash.
        For example:
 
        `https://github.com/foo/bar` yields `["foo", "bar"]`
        `https://github.com/foo/bar/` yields `["foo", "bar"]`
        `https://github.com/` yields `[]`
     */
    private var pathComponents: [String] {
        var components = path.components(separatedBy: "/")
        if components.last == "" {
            components.removeLast()
        }
        return components
    }
    
    /// Returns a new URI with the provided path.
    private func withPath(_ path: String) -> URI {
        return URI(
            scheme: scheme,
            userInfo: userInfo,
            hostname: hostname,
            port: port,
            path: path,
            query: query,
            rawQuery: rawQuery,
            fragment: fragment
        )
    }
    
    /**
        The last path component of the URL, if there is a path.
        Otherwise returns `nil`.
     */
    public var lastPathComponent: String? {
        return pathComponents.last
    }
    
    /**
        - returns: a new URI without the path of the receiver.
     */
    public func removingPath() -> URI {
        return withPath("")
    }
    
    /**
        Constructs a new URI by appending the specified path component.
        - parameters:
            - pathComponent: The component to add to the path
            - isDirectory: If true, then the resulting path will have
                           a trailing '/'
     */
    public func appendingPathComponent(_ pathComponent: String, isDirectory: Bool = false) -> URI {
        var components = pathComponents
        components.append(pathComponent)
        if isDirectory {
            components.append("")
        }
        return withPath(components.joined(separator: "/"))
    }
    
    /**
        Constructs a new URI by removing the last path component.
        If the path is empty, the result is the same URI.
     */
    public func deletingLastPathComponent() -> URI {
        if path.isEmpty { return self }
        var components = pathComponents
        if components.isEmpty { return self }
        components.removeLast()
        return withPath(components.joined(separator: "/"))
    }
}
