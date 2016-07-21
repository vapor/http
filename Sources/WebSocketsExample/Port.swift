import Foundation

extension ProcessInfo {
    static func arguments() -> [String] {
        return ProcessInfo.processInfo.arguments
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
