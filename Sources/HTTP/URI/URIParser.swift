import CHTTP

extension URI {
    enum URIComponent {
        case scheme, hostname, port, path, query, fragment, userinfo
        
        func extract(from uri: http_parser_url) -> (Int, Int) {
            let data: http_parser_url_field_data
            
            switch self {
            case .scheme:
                data = uri.field_data.0
            case .hostname:
                data = uri.field_data.1
            case .port:
                data = uri.field_data.2
            case .path:
                data = uri.field_data.3
            case .query:
                data = uri.field_data.4
            case .fragment:
                data = uri.field_data.5
            case .userinfo:
                data = uri.field_data.6
            }
            
            return (numericCast(data.off), numericCast(data.len))
        }
        
        var previousComponent: URIComponent? {
            switch self {
            case .scheme: return nil
            case .userinfo: return .scheme
            case .hostname: return .userinfo
            case .port: return .hostname
            case .path: return .port
            case .query: return .path
            case .fragment: return .query
            }
        }
    }
    
    func parse(_ component: URIComponent) -> String? {
        guard let (start, end) = boundaries(of: component) else {
            return nil
        }
        
        return String(bytes: buffer[start..<end], encoding: .utf8)
    }
    
    mutating func update(_ component: URIComponent, to string: String?) {
        var component = component
        
        guard let (start, end) = boundaries(of: component) else {
            guard let string = string else {
                return
            }
            
            let url = uriParser()
            
            while let previousComponent = component.previousComponent {
                component = previousComponent
                let (_, end) = previousComponent.extract(from: url)
                
                self.buffer.insert(contentsOf: string.utf8, at: end)
            }
            
            self.buffer.insert(contentsOf: string.utf8, at: 0)
            return
        }
        
        if let string = string {
            self.buffer.replaceSubrange(start..<end, with: string.utf8)
        } else {
            self.buffer.removeSubrange(start..<end)
        }
    }
    
    func uriParser() -> http_parser_url {
        // create url results struct
        var url = http_parser_url()
        http_parser_url_init(&url)
        
        // parse url
        self.buffer.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: buffer.count) { pointer in
                let status = http_parser_parse_url(pointer, buffer.count, 0, &url)
                assert(status == 0, "URL parser error: \(status)")
            }
        }
        
        return url
    }
    
    func boundaries(of component: URIComponent) -> (Int, Int)? {
        let (offset, length) = component.extract(from: uriParser())
        
        if length == 0 {
            return nil
        }
        
        return (offset, offset &+ length)
    }
}
