import Async
import Bits

public final class ProtocolTester: Async.OutputStream {
    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer

    /// Stream being tested
    public var downstream: AnyInputStream<ByteBuffer>?

    /// See `OutputStream.output`
    public func output<S>(to inputStream: S) where S: Async.InputStream, ProtocolTester.Output == S.Input {
        downstream = .init(inputStream)
    }

    /// Callback to indicate test is restarting
    private var reset: () -> ()

    /// Callback to indicate a test failure
    private var fail: (String, StaticString, UInt) -> ()

    /// The added checks
    private var checks: [ProtocolTesterCheck]

    /// The original string data
    private let original: String

    /// The test data
    private var data: Bytes

    /// Creates a new `ProtocolTester`
    public init(data: String, onFail: @escaping (String, StaticString, UInt) -> (), reset: @escaping () -> ()) {
        self.reset = reset
        self.fail = onFail
        self.original = data
        self.data = Bytes(data.utf8)
        checks = []
    }

    /// Adds a "before" offset assertion to the tester.
    public func assert(before substring: String, file: StaticString = #file, line: UInt = #line, callback: @escaping () throws -> ()) {
        let check = ProtocolTesterCheck(minOffset: nil, maxOffset: original.offset(of: substring), expectSuccess: true, file: file, line: line, checks: callback)
        checks.append(check)
    }

    /// Adds an "after" offset assertion to the tester.
    public func assert(after substring: String, file: StaticString = #file, line: UInt = #line, callback: @escaping () throws -> ()) {
        let check = ProtocolTesterCheck(minOffset: original.offset(of: substring), maxOffset: nil, expectSuccess: true, file: file, line: line, checks: callback)
        checks.append(check)
    }

    /// Runs the protocol tester w/ the supplied input
    public func run() -> Future<Void> {
        Swift.assert(downstream != nil, "ProtocolTester must be connected before running")
        return runMax(ByteBuffer(start: &data, count: data.count), max: data.count)
    }

    /// Recurisvely runs tests, splitting the supplied buffer until max == 0
    private func runMax(_ buffer: ByteBuffer, max: Int) -> Future<Void> {
        if max > 0 {
            let maxSizedChunksCount = buffer.count / max
            let lastChunkSize = buffer.count % max

            var chunks: [ByteBuffer] = []

            for i in 0..<maxSizedChunksCount {
                let maxSizedChunk = ByteBuffer(start: buffer.baseAddress?.advanced(by: i * max), count: max)
                chunks.insert(maxSizedChunk, at: 0)
            }

            if lastChunkSize > 0 {
                let lastChunk = ByteBuffer(start: buffer.baseAddress?.advanced(by: buffer.count - lastChunkSize), count: lastChunkSize)
                chunks.insert(lastChunk, at: 0)
            }
            
            reset()
            return runChunks(chunks, currentOffset: 0).flatMap(to: Void.self) {
                return self.runMax(buffer, max: max - 1)
            }
        } else {
            downstream?.close()
            return .done
        }
    }

    /// Recursively passes each chunk to downstream until chunks.count == 0
    private func runChunks(_ chunks: [ByteBuffer], currentOffset: Int) -> Future<Void> {
        var chunks = chunks
        if let chunk = chunks.popLast() {
            runChecks(offset: currentOffset, chunks: chunks)
            return downstream!.next(chunk).flatMap(to: Void.self) { _ in
                return self.runChunks(chunks, currentOffset: currentOffset + chunk.count)
            }
        } else {
            runChecks(offset: currentOffset, chunks: chunks)
            return .done
        }
    }

    /// Runs checks for the supplied offset.
    private func runChecks(offset: Int, chunks: [ByteBuffer]) {
        for check in checks {
            var shouldRun = false
            if let min = check.minOffset, offset >= min {
                shouldRun = true
            }
            if let max = check.maxOffset, offset < max {
                shouldRun = true
            }
            if shouldRun {
                do {
                    try check.checks()
                } catch {
                    var message = "Protocol test failed: \(error)"
                    let data = chunks.reversed().map { "[" + ProtocolTester.dataDebug(for: $0) + "]" }.joined(separator: " ")
                    let text = chunks.reversed().map { "[" + ProtocolTester.textDebug(for: $0) + "]" }.joined(separator: " ")
                    message += "\nData: \(data)"
                    message += "\nText: \(text)"
                    self.fail(message, check.file, check.line)
                }
            }
        }
    }

    /// Creates TEXT formatted debug string for a ByteBuffer
    private static func textDebug(for buffer: ByteBuffer) -> String {
        let string = String(bytes: buffer, encoding: .ascii) ?? "n/a"
        return string
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Create HEX formatted debug string for a ByteBuffer
    private static func dataDebug(for buffer: ByteBuffer) -> String {
        var string = "0x"
        for i in 0..<buffer.count {
            let byte = buffer[i]
            let upper = Int(byte >> 4)
            let lower = Int(byte & 0b00001111)
            string.append(hexMap[upper])
            string.append(hexMap[lower])
        }
        return string
    }

    /// HEX map.
    private static let hexMap = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "0"]
}

/// A stored protocol tester check.
private struct ProtocolTesterCheck {
    var minOffset: Int?
    var maxOffset: Int?
    var expectSuccess: Bool
    var file: StaticString
    var line: UInt
    var checks: () throws -> ()
}

extension String {
    /// Returns int offset of the supplied string, crashing if it doesn't exist
    fileprivate func offset(of string: String) -> Int {
        return range(of: string)!.upperBound.encodedOffset
    }
}

extension String: Error {}
