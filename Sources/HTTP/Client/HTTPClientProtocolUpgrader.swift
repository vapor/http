/// Can be used to upgrade `HTTPClient` requests using the static `HTTPClient.upgrade(...)` method.
public protocol HTTPClientProtocolUpgrader {
    /// Builds the `HTTPHeaders` required for an upgrade.
    func buildUpgradeRequest() -> HTTPHeaders

    /// Returns `true` if the `HTTPResponseHead` is valid. If `false`,
    /// the upgrade will be aborted.
    func isValidUpgradeResponse(_ upgradeResponse: HTTPResponseHead) -> Bool

    /// Called if `isValidUpgradeResponse` returns `true`. This should return the `UpgradeResult`
    /// that will ultimately be returned by `HTTPClient.upgrade(...)`.
    func upgrade(ctx: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<Void>
}
