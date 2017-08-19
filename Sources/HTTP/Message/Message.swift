public protocol Message: Codable {
    var version: Version { get set }
    var headers: Headers { get set }
    // FIXME
    // var body: Body { get set }
}
