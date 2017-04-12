
extension Version {
    static func makeParsed<S: Sequence>(with bytes: S) throws -> Version where S.Iterator.Element == Byte {
        // ["HTTP", "1.1"]
        let comps = bytes.split(
            separator: .forwardSlash,
            maxSplits: 1,
            omittingEmptySubsequences: true
        )

        guard
            comps.count == 2
            else { throw ParserError.invalidVersion }

        let version = comps[1].split(
            separator: .period,
            maxSplits: 1,
            omittingEmptySubsequences: true
        )


        func versionNumber(for index: Int) throws -> Int? {
            if version.count > index {
                guard let major = version[index].decimalInt else { throw ParserError.invalidVersion }
                return major
            }
            return nil
        }

        guard
            let major = try versionNumber(for: 0)
            else { throw ParserError.invalidVersion }

        guard
            let minor = try versionNumber(for: 1)
            else { return Version(major: major) }

        guard
            let patch = try versionNumber(for: 2)
            else { return Version(major: major, minor: minor) }

        return Version(major: major, minor: minor, patch: patch)
    }
}
