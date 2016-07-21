/**
    ehlo-line    ::= ehlo-keyword *( SP ehlo-param )
*/
struct EHLOExtension {
    let keyword: String
    let params: [String]

    init(_ line: String) throws {
        let args = line.components(separatedBy: " ")
        guard let keyword = args.first, !keyword.isEmpty else { throw Error.missingKeyword }
        self.keyword = keyword
        self.params = args.dropFirst().array // rm keyword
    }
}

extension Sequence where Iterator.Element == EHLOExtension {
    var authExtension: EHLOExtension? {
        return self.lazy.filter { $0.keyword.equals(caseInsensitive: "AUTH") } .first
    }
}

extension EHLOExtension {
    enum Error: Swift.Error {
        case missingKeyword
    }
}
