import Foundation

extension ProcessInfo {
    static func arguments() -> [String] {
        #if os(Linux)
            return ProcessInfo.processInfo().arguments
        #else
            return ProcessInfo.processInfo.arguments
        #endif
    }
}

let port = ProcessInfo
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
