/// The location of a `Name: Value` pair in the raw HTTP headers data.
struct HTTPHeaderIndex {
    /// Start offset of the header's name field.
    var nameStartIndex: Int
    /// End offset of the header's name field
    var nameEndIndex: Int

    /// Start offset of the header's value field.
    var valueStartIndex: Int
    /// End offset of the header's value field.
    var valueEndIndex: Int
}

extension HTTPHeaderIndex {
    /// The lowest index of this header.
    var startIndex: Int {
        return nameStartIndex
    }

    /// The highest index of this header.
    var endIndex: Int {
        return valueEndIndex + 2 // include trailing \r\n
    }

    /// The length of this header.
    var size: Int {
        return endIndex - startIndex
    }
}

extension HTTPHeaderIndex: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    var description: String {
        return "[\(nameStartIndex)..<\(nameEndIndex):\(valueStartIndex)..<\(valueEndIndex)]"
    }

}
