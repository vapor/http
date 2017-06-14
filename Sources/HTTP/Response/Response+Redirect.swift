public enum RedirectType {
    /// A permanent redirect
    case permanent // 301 permanent
    /// Forces the redirect to come with a GET, regardless of req method
    case normal // 303 see other
    /// Maintains original request method, ie: PUT will call PUT on redirect
    case temporary // 307 temporary
}

extension RedirectType {
    fileprivate var status: Status {
        switch self {
        case .permanent:
            return .permanentRedirect
        case .normal:
            return .seeOther
        case .temporary:
            return .temporaryRedirect
        }
    }
}
extension Response {
    /// Creates a redirect response.
    ///
    /// Set permanently to 'true' to allow caching to automatically
    /// redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public convenience init(
        headers: [HeaderKey: String] = [:],
        redirect location: String,
        permanently: Bool = false
    ) {
        self.init(
            headers: headers,
            redirect: location,
            type: permanently ? .permanent : .normal
        )
    }
}

extension Response {
    /// Creates a redirect response.
    ///
    /// Set permanently to 'true' to allow caching to automatically
    /// redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public convenience init(
        headers: [HeaderKey: String] = [:],
        redirect location: String,
        type: RedirectType = .normal
    ) {
        var headers = headers
        headers["Location"] = location
        self.init(status: type.status, headers: headers)
    }
}


