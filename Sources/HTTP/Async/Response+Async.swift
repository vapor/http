/*
    Temporarily not available on Linux until Foundation's 'Dispatch apis are available
*/

#if !os(Linux)

    import Foundation

    extension Response {
        /**
            Sometimes, asynchronicity is required within Vapor's synchronous environment. 
            Use this function to enter an async context in which the 'promise' object can
            be passed to multiple threads and called when appropriate
        */
        public static func async(
            timingOut timeout: DispatchTime = .distantFuture,
            _ handler: (Promise<ResponseRepresentable>) throws -> Void
        ) throws -> ResponseRepresentable {
            return try Promise.async(timingOut: timeout, handler)
        }
    }
#endif
