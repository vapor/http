import Dispatch

internal class ThreadsafeArray<T:Equatable> : Sequence {
    typealias ArrayType = Array<T>
    private var elements = ArrayType()
    private let queue = DispatchQueue(label: "codes.vapor.threadsafearray", attributes: .concurrent)
    
    public func makeIterator() -> ArrayType.Iterator {
        var iterator: ArrayType.Iterator!
        queue.sync {
            iterator = elements.makeIterator()
        }
        return iterator
    }
    
    public func append(_ element: T) {
        queue.async(flags: .barrier) {
            self.elements.append(element)
        }
    }
    
    public func remove(_ element:T) {
        queue.async(flags: .barrier) {
            let index = self.elements.index{ $0 == element }
            guard let i = index else { return }
            self.elements.remove(at: i)
        }
    }
    
    public var count: Int {
        var count = 0
        queue.sync {
            count = elements.count
        }
        
        return count
    }
    
    public var first:T? {
        var element: T?
        queue.sync {
            element = elements.first
        }
        return element
    }
    
    public subscript(index: Int) -> T {
        set {
            queue.async(flags: .barrier) {
                self.elements[index] = newValue
            }
        }
        get {
            var element: T!
            queue.sync {
                element = elements[index]
            }
            return element
        }
    }
}
