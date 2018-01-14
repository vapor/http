extension TrieRouterNode {
    fileprivate func find(constants: [[UInt8]]) -> TrieRouterNode<Output> {
        let constant = constants[0]
        
        let node: TrieRouterNode<Output>
        
        if let found = self.findConstant(constant) {
            node = found
        } else {
            node = TrieRouterNode<Output>(kind: .constant(data: constant, dataSize: constant.count))
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
                return TrieRouterNode<Output>(kind: .parameter(data: p.bytes))
            }
        case .anything:
            if let node = findAnyNode() {
                return node
            } else {
                return TrieRouterNode<Output>(kind: .anything)
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
    
//    fileprivate func set(component: PathComponent, to node: TrieRouterNode<Output>) {
        switch component {
        case .constants(let constants):
            if constants.count == 0 {
                self.kind = node.kind
                self.output = node.output
                self.children = node.children
            } else {
                for i in 0..<self.children.count {
                    if case .constant(let data, _) = children[i].kind, constants[0].bytes == data {
                        if constants.count == 1 {
                            children[i].kind = node.kind
                            children[i].output = node.output
                            children[i].children = node.children
                        } else {
                            children[i].set(component: .constants(Array(constants[1...])), to: node)
                        }
                        
                        return
                    }
                }
                
                var child = TrieRouterNode<Output>(kind:
                    .constant(data: constants[0].bytes, dataSize: constants[0].bytes.count)
                )
                
                child.set(component: .constants(Array(constants[1...])), to: node)
                
                self.children.append(child)
            }
        case .parameter(let p):
            for i in 0..<self.children.count {
                if case .parameter = self.children[i].kind {
                    var child = self.children[i]
                    
                    child.kind = node.kind
                    child.output = node.output
                    child.children = node.children
                    
                    return
                }
            }
            
            var child = TrieRouterNode<Output>(kind: .parameter(data: p.bytes))
            
            child.kind = node.kind
            child.output = node.output
            child.children = node.children
            
            self.children.append(child)
        case .anything:
            for i in 0..<self.children.count {
                if case .anything = self.children[i].kind {
                    var child = self.children[i]
                    
                    child.kind = node.kind
                    child.output = node.output
                    child.children = node.children
                    
                    return
                }
            }
            
            var child = TrieRouterNode<Output>(kind: .anything)
            
            child.kind = node.kind
            child.output = node.output
            child.children = node.children
            
            self.children.append(child)
        }
    }
    
    subscript(path: PathComponent) -> TrieRouterNode<Output> {
        get {
            return self.find(component: path)
        }
        set {
            self.set(component: path, to: newValue)
        }
    }
    
    subscript(path: [PathComponent]) -> TrieRouterNode<Output> {
        get {
            if path.count == 1 {
                return self[path[0]]
            } else {
                return self[path[0]][Array(path[1...])]
            }
        }
        set {
            if path.count == 1 {
                self[path[0]] = newValue
            } else {
                self[path[0]][Array(path[1...])] = newValue
            }
        }
    }
}
