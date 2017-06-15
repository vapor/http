/// Specifies the type of redirect
/// that the client should receive
public enum RedirectType {
    /// A cacheable redirect
    case permanent // 301 permanent
    /// Forces the redirect to come with a GET, regardless of req method
    case normal // 303 see other
    /// Maintains original request method, ie: PUT will call PUT on redirect
    case temporary // 307 temporary
}

extension Response {
    /// Creates a redirect response.
    ///
    /// Set type to '.permanently' to allow caching to automatically
    /// redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public convenience init(
        headers: [HeaderKey: String] = [:],
        redirect location: String,
        _ type: RedirectType = .normal
    ) {
        var headers = headers
        headers["Location"] = location
        self.init(status: type.status, headers: headers)
    }
}

extension RedirectType {
    fileprivate var status: Status {
        switch self {
        case .permanent:
            return .movedPermanently
        case .normal:
            return .seeOther
        case .temporary:
            return .temporaryRedirect
        }
    }
}

/// DEPRECATED:

extension Response {
    /// Creates a redirect response.
    ///
    /// Set permanently to 'true' to allow caching to automatically
    /// redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    @available(
        *,
        deprecated: 2.1,
        message: "Use new redirect w/ specified type, .permanent, .normal, or .temporary. To recreate existing behavior, 'true == .permanent, false == .normal'."
    )
    public convenience init(
        headers: [HeaderKey: String] = [:],
        redirect location: String,
        permanently: Bool
    ) {
        self.init(
            headers: headers,
            redirect: location,
            permanently ? .permanent : .normal
        )
    }
}
