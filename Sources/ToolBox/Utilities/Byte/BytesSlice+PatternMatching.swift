public func ~=(pattern: Bytes, value: BytesSlice) -> Bool {
    return BytesSlice(pattern) == value
}

public func ~=(pattern: BytesSlice, value: BytesSlice) -> Bool {
    return pattern == value
}
