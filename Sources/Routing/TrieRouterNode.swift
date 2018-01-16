import Foundation
import Bits

final class TrieRouterNode<Output> {
    /// Kind of node
    var kind: TrieRouterNodeKind

    /// All constant child nodes
    var children: [TrieRouterNode<Output>]

    /// This node's output
    var output: Output?

    init(
        kind: TrieRouterNodeKind,
        children: [TrieRouterNode<Output>] = [],
        output: Output? = nil
    ) {
        self.kind = kind
        self.children = children
        self.output = output
    }
}

enum TrieRouterNodeKind {
    case root
    
    // Size is separate to save ARC performance, which had a huge impact here
    case parameter(data: [UInt8])
    
    case constant(data: [UInt8], dataSize: Int)
    
    case anything
}
