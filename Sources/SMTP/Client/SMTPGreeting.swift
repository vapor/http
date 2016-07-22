internal struct SMTPGreeting {
    let domain: String
    let greeting: String

    init(_ line: String) throws {
        let split = line
            .bytes
            .split(separator: .space, maxSplits: 1)
            .map { $0.string }
        guard split.count >= 1 else { throw Error.missingDomain }
        domain = split[0]
        greeting = split[safe: 1] ?? ""
    }
}

extension SMTPGreeting {
    enum Error: Swift.Error {
        case missingDomain
    }
}
