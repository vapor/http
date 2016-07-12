import Foundation

#if !os(Linux)
    /*
     Temporary work around since things have different names on linux
     */
    typealias NSProcessInfo = ProcessInfo
#endif


extension NSProcessInfo {
    static func arguments() -> [String] {
        #if !os(Linux)
            return NSProcessInfo.processInfo.arguments
        #else
            return NSProcessInfo.processInfo().arguments
        #endif
    }
}
let port = NSProcessInfo
    .arguments()
    .lazy
    .filter { $0.hasPrefix("--port=") }
    .first?
    .characters
    .split(separator: "=")
    .last
    .flatMap { String($0) }
    .flatMap { Int($0) }
    ?? 8080
