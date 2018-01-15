extension TrieRouterNode {
    fileprivate func find(constants: [[UInt8]]) -> TrieRouterNode<Output> {
        let constant = constants[0]
        
        let node: TrieRouterNode<Output>
        
        if let found = self.findConstant(constant) {
            node = found
        } else {
            node = TrieRouterNode<Output>(kind: .constant(data: constant, dataSize: constant.count))
            self.children.append(node)
        }
        
        if constants.count > 1 {
            return node.find(constants: Array(constants[1...]))
        } else {
            return node
        }
    }
    
    fileprivate func find(component: PathComponent) -> TrieRouterNode<Output> {
        switch component {
        case .constants(let constants):
            if constants.count == 0 {
                return self
            } else {
                return self.find(constants: constants.map { $0.bytes })
            }
        case .parameter(let p):
            if let node = self.findParameterNode() {
                return node
            } else {
                let node = TrieRouterNode<Output>(kind: .parameter(data: p.bytes))
                self.children.append(node)
                return node
            }
        case .anything:
            if let node = findAnyNode() {
                return node
            } else {
                let node = TrieRouterNode<Output>(kind: .anything)
                self.children.append(node)
                return node
            }
        }
    }
    
    /// Returns the first parameter node
    fileprivate func findParameterNode() -> TrieRouterNode<Output>? {
        for child in children {
            if case .parameter = child.kind {
                return child
            }
        }
        
        return nil
    }
    
    func findConstant(_ buffer: [UInt8]) -> TrieRouterNode? {
        for child in children {
            if case .constant(let data, _) = child.kind, data == buffer {
                return child
            }
        }
        
        return nil
    }
    
    fileprivate func findAnyNode() -> TrieRouterNode? {
        for child in children {
            if case .anything = child.kind {
                return child
            }
        }
        
        return nil
    }
    
    subscript(path: PathComponent) -> TrieRouterNode<Output> {
        return self.find(component: path)
    }
}
