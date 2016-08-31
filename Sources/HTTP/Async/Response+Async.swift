import Foundation

extension Response {
    /**
        Sometimes, asynchronicity is required within Vapor's synchronous environment. 
        Use this function to enter an async context in which the 'promise' object can
        be passed to multiple threads and called when appropriate
    */
    public static func async(
        timeout: Double = 999_999_999,
        _ handler: @escaping (Portal<ResponseRepresentable>) throws -> Void
    ) throws -> ResponseRepresentable {
        return try Portal.open(timeout: timeout, handler)
    }
}
