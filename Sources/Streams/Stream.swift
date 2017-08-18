/// A stream of generic information
public protocol Stream {
    /// The contents of this stream
    associatedtype Output
    
    /// Maps this stream to a stream of other information
    func map<T>(_ closure: @escaping ((Output) throws -> (T?))) -> StreamTransformer<Output, T>
}

extension Stream {
    public func then(_ closure: @escaping ((Output) throws -> (Void))) {
        _ = self.map(closure)
    }
}

/// A helper that allows you to transform streams
open class StreamTransformer<From, To> : Stream {
    /// The input, that's being transformed
    public typealias Input = From
    
    /// The resulting output
    public typealias Output = To
    
    /// The transformer used to achieve the transformation from the input to the output
    let transformer: ((Input) throws -> (Output?))
    
    /// Creates a new StreamTransformer using a closure
    public init(using closure: @escaping ((Input) throws -> (Output?))) {
        self.transformer = closure
    }
    
    /// Transforms the incoming data
    public func process(_ input: Input) throws {
        if let output = try transformer(input) {
            for stream in branchStreams {
                try stream(output)
            }
        }
    }

    /// Maps the output to this stream to yet another transformed stream
    public func map<T>(_ closure: @escaping ((Output) throws -> (T?))) -> StreamTransformer<Output, T> {
        let stream = StreamTransformer<Output, T>(using: closure)
        
        branchStreams.append(stream.process)
        
        return stream
    }
    
    /// Internal typealias used to define a cascading callback
    fileprivate typealias ProcessOutputCallback = ((Output) throws -> ())
    
    /// An internal array, used to keep track of all closures waiting for more data from this stream
    fileprivate var branchStreams = [ProcessOutputCallback]()
}
