import libc

extension UInt8 {
    public static func random() -> UInt8 {
        let max = UInt32(UInt8.max)
        #if os(Linux)
            let val = UInt8(libc.random() % Int(max))
        #else
            let val = UInt8(arc4random_uniform(max))
        #endif
        return val
    }
}
