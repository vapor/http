extension HTTPMessage {
    /// The MediaType inside the `Message` `Headers`' "Content-Type"
    public var mediaType: MediaType? {
        get {
            guard let contentType = headers[.contentType].first else {
                return nil
            }

            return MediaType.parse(contentType)
        }
        set {
            if let new = newValue?.serialize() {
                headers.replaceOrAdd(name: .contentType, value: new)
            } else {
                headers.remove(name: .contentType)
            }
        }
    }
}
