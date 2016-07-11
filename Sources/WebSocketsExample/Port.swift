import Foundation

#if !os(Linux)
    /*
        Temporary work around since things have different names on linux
    */
    typealias NSProcessInfo = ProcessInfo
#endif

let port = NSProcessInfo.processInfo()
    .arguments
    .lazy
    .filter { $0.hasPrefix("--port=") }
    .first?
    .characters
    .split(separator: "=")
    .last
    .flatMap { String($0) }
    .flatMap { Int($0) }
    ?? 8080
