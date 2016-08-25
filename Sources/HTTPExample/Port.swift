import Foundation

let port = CommandLine
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
