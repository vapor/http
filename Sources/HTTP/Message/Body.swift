import Foundation

public struct Body: Codable {
    public var data: Data

    public init(_ data: Data = Data()) {
        self.data = data
    }
}

public protocol BodyRepresentable {
    func makeBody() throws -> Body
}

extension String: BodyRepresentable {
    public func makeBody() throws -> Body {
        let data = self.data(using: .utf8) ?? Data()
        return Body(data)
    }
}
