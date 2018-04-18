/// Represents a `MediaType` and its associated preference, `q`.
public struct MediaTypePreference {
    /// The `MediaType` in question.
    public var mediaType: MediaType

    /// Its associated preference.
    public var q: Double?
}

extension Array where Element == MediaTypePreference {
    /// Parses an array of `[MediaTypePreference]` from an accept header value
    ///
    /// - parameters:
    ///     - data: The accept header value to parse.
    public static func parse(_ data: LosslessDataConvertible) -> [MediaTypePreference] {
        return data.convertToData().split(separator: .comma).compactMap { token in
            let parts = token.split(separator: .semicolon, maxSplits: 1)
            guard let value = String(data: parts[0], encoding: .utf8)?.trimmingCharacters(in: .whitespaces) else {
                return nil
            }
            guard let mediaType = MediaType.parse(value) else {
                return nil
            }
            switch parts.count {
            case 1: return .init(mediaType: mediaType, q: nil)
            case 2:
                let qparts = parts[1].split(separator: .equals, maxSplits: 1)
                guard qparts.count == 2 else {
                    return nil
                }
                guard let preference = String(data: qparts[1], encoding: .ascii).flatMap(Double.init) else {
                    return nil
                }
                return .init(mediaType: mediaType, q: preference)
            default: return nil
            }
        }
    }

    /// Returns all `MediaType`s in this array of `MediaTypePreference`.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    public var mediaTypes: [MediaType] {
        return map { $0.mediaType }
    }

    /// Returns `ComparisonResult` comparing the supplied `MediaType`s against these preferences.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public func comparePreference(for a: MediaType, to b: MediaType) -> ComparisonResult {
        var aq: Double?
        var bq: Double?
        for pref in self {
            if aq == nil, pref.mediaType == a { aq = pref.q ?? 1.0 }
            if bq == nil, pref.mediaType == b { bq = pref.q ?? 1.0 }
        }
        switch (aq, bq) {
        case (.some(let aq), .some(let bq)):
            /// there is a value for both media types, compare the preference
            if aq == bq {
                return .orderedSame
            } else if aq > bq {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        case (.none, .some):
            /// there is not a value for a, no way it can be preferred
            return .orderedDescending
        case (.some, .none):
            /// there is not a value for b, a is preferred by default
            return .orderedAscending
        case (.none, .none):
            /// there is no value for either, neither is preferred
            return .orderedSame
        }
    }
}
