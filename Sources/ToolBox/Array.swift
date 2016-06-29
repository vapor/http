extension Array {
    public func chunked(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map { startIndex in
            let next = startIndex.advanced(by: size)
            let end = next <= endIndex ? next : endIndex
            return Array(self[startIndex ..< end])
        }
    }
}
