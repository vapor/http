import Async
import HTTP
import Foundation
import Bits

/// A basic router that can route requests depending on the method and URI
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/router/)
public final class TrieRouter<Output> {
    /// All routes registered to this router
    public private(set) var routes: [Route<Output>] = []
    
    /// The root node
    var root: TrieRouterNode<Output>
    
    /// If a route cannot be found, this is the fallback responder that will be used instead
    public var fallback: Output?

    /// Create a new trie router
    public init() {
        self.root = TrieRouterNode<Output>(kind: .root)
    }

    /// See Router.register()
    public func register(route: Route<Output>) {
        self.routes.append(route)
        var current = root
        
        for component in route.path {
            current = current[component]
        }
        
        current.output = route.output
    }

    /// See Router.route()
    public func route(path: [PathComponent.Parameter], parameters: ParameterContainer) -> Output? {
        // always start at the root node
        var current: TrieRouterNode = root
        var parameterNode: (TrieRouterNode<Output>, [UInt8])?
        var fallbackNode: TrieRouterNode<Output>?

        // traverse the constant path supplied
        nextComponent: for component in path {
            // Reset state to ensure a previous resolved path isn't interfering
            parameterNode = nil
            fallbackNode = nil
            
            for child in current.children {
                switch child.kind {
                case .anything:
                    fallbackNode = child
                case .constant(let data, let size):
                    // if we find a constant route path that matches this component,
                    // then we should use it.
                    let match = component.withByteBuffer { buffer in
                        return memcmp(data, buffer.baseAddress!, size) == 0
                    }
                    
                    if match {
                        current = child
                        continue nextComponent
                    }
                case .parameter(let parameter):
                    parameterNode = (child, parameter)
                case .root:
                    fatalError("Incorrect nested 'root' routing node")
                }
            }
            
            if let (node, parameter) = parameterNode {
                // if no constant routes were found that match the path, but
                // a dynamic parameter child was found, we can use it
                let lazy = ParameterValue(slug: parameter, value: component.bytes)
                parameters.parameters.append(lazy)
                current = node
                continue nextComponent
            }
            
            guard let fallbackNode = fallbackNode else {
                // No results found
                return fallback
            }
            
            current = fallbackNode
        }
        
        // return the resolved responder if there hasn't
        // been an early exit.
        return current.output ?? fallback
    }
}
