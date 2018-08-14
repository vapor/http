import Bits

/// A basic username and password.
public struct BasicAuthorization {
    /// The username, sometimes an email address
    public let username: String
    
    /// The plaintext password
    public let password: String
    
    /// Create a new `BasicAuthorization`.
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

extension HTTPHeaders {
    /// Access or set the `Authorization: Basic: ...` header.
    public var basicAuthorization: BasicAuthorization? {
        get {
            guard let string = self[.authorization].first else {
                return nil
            }
            
            guard let range = string.range(of: "Basic ") else {
                return nil
            }
            
            let token = string[range.upperBound...]
            guard let decodedToken = Data(base64Encoded: .init(token)) else {
                return nil
            }
            
            let parts = decodedToken.split(separator: .colon)
            
            guard parts.count == 2 else {
                return nil
            }
            
            guard
                let username = String(data: parts[0], encoding: .utf8),
                let password = String(data: parts[1], encoding: .utf8)
                else {
                    return nil
            }
            
            return .init(username: username, password: password)
        }
        set {
            if let basic = newValue {
                let credentials = "\(basic.username):\(basic.password)"
                let encoded = Data(credentials.utf8).base64EncodedString()
                replaceOrAdd(name: .authorization, value: "Basic \(encoded)")
            } else {
                remove(name: .authorization)
            }
        }
    }
}
