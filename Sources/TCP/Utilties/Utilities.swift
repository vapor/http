/// Infinitely loop over a collection.
/// Used to supply server worker queues to clients.
internal struct LoopIterator<Base: Collection>: IteratorProtocol {
    private let collection: Base
    private var index: Base.Index

    public init(collection: Base) {
        self.collection = collection
        self.index = collection.startIndex
    }

    public mutating func next() -> Base.Iterator.Element? {
        guard !collection.isEmpty else {
            return nil
        }

        let result = collection[index]
        collection.formIndex(after: &index) // (*) See discussion below
        if index == collection.endIndex {
            index = collection.startIndex
        }
        return result
    }
}

#if os(Linux)
import libc

// fix some constants on linux
let SOCK_STREAM = Int32(libc.SOCK_STREAM.rawValue)
let IPPROTO_TCP = Int32(libc.IPPROTO_TCP)
#endif
