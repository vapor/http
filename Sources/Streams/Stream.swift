public protocol Stream {
    associatedtype Streamable
    
    func map<T, S : Stream>(_ closure: ((Streamable) -> (T?))) -> S where S.Streamable == T
}
