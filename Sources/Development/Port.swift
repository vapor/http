import Foundation

#if !os(Linux)
    /*
        Temporary work around since things have different names on linux
    */
    typealias NSProcessInfo = ProcessInfo
#endif

let portArgument = NSProcessInfo.processInfo()
    .arguments
    .lazy
    .filter { $0.hasPrefix("--port=") }
    .first?
    .characters
    .dropFirst("--port=".characters.count)

let port = Int(String(portArgument)) ?? 8080
