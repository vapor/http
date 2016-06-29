extension String {
    public func finished(with end: String) -> String {
        guard !self.hasSuffix(end) else {
            return self
        }

        return self + end
    }
}
