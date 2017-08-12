import Bits
import Sockets
import Transport

public final class WebSocket {

    public enum State {
        case open
        case closing
        case closed
    }

    public enum Mode {
        case client, server

        public var maskOutgoingMessages: Bool {
            // RFC: Client must mask messages
            return self == .client
        }

        public func makeKey() -> Frame.MaskingKey {
            return .make(isMasked: maskOutgoingMessages)
        }
    }

    // MARK: All Frames

    public var onFrame: ((WebSocket, Frame) throws -> ())? = nil

    // MARK: Non Control Frames

    public var onText: ((WebSocket, String) throws -> ())? = nil
    public var onBinary: ((WebSocket, Bytes) throws -> ())? = nil

    // MARK: Non Control Extensions

    public var onNonControlExtension: ((WebSocket, Frame.OpCode.NonControlFrameExtension, Bytes) throws -> ())? = nil

    // MARK: Control Frames

    public var onPing: ((WebSocket, Bytes) throws -> ())? = nil
    public var onPong: ((WebSocket, Bytes) throws -> ())? = nil

    // MARK: Control Frame Extensions

    public var onControlExtension:
        ((WebSocket, Frame.OpCode.ControlFrameExtension, Bytes) throws -> ())? = nil

    // MARK: Close: (Control Frame)

    public var onClose: ((WebSocket, UInt16?, String?, Bool) throws -> ())? = nil

    // MARK: Attributes

    public fileprivate(set) var state: State

    internal let mode: Mode
    internal let stream: DuplexStream // FIXME: generic

    fileprivate let aggregator: FragmentAggregator?

    // MARK: Initialization

    /**
     Aggregator should only be disabled in situations where the aggregator is customized.
     Fragmented messages will only be delivered through `onFrame`
     */
    public init(_ stream: DuplexStream, mode: Mode, disableFragmentAggregation: Bool = false) {
        self.mode = mode
        self.state = .open
        self.stream = stream

        if disableFragmentAggregation {
            self.aggregator = nil
        } else {
            self.aggregator = FragmentAggregator()
        }
    }
}

// MARK: Listen

/**
 [WARNING] **********
 Sensitive code below, ensure you are fully familiar w/ various control flows and protocols
 before changing or moving things including access control
 */
extension WebSocket {
    /**
     Tells the WebSocket to begin accepting frames

     If you're using built in Vapor syntax you should NOT call this manually.
     */
    public func listen() throws {
        let parser = FrameParser(stream: stream)
        try loop(with: parser)
    }

    /**
     [WARNING] - deserializer MUST be declared OUTSIDE of while-loop
     to prevent losing bytes trapped in the buffer. ALWAYS pass deserializer
     as argument
     */
    private func loop(with parser: FrameParser) throws {
        while state != .closed {
            // not a part of while logic, we need to separately acknowledge
            // that TCP closed w/o handshake
            if stream.isClosed {
                try completeCloseHandshake(statusCode: nil, reason: nil, cleanly: false)
                break
            }

            do {
                let frame = try parser.acceptFrame()
                try received(frame)
            } catch {
                if let recError = error as? SocketsError, recError.number == 35  {
                    continue
                }
                try completeCloseHandshake(statusCode: nil, reason: nil, cleanly: false)
            }
        }
    }

    private func received(_ frame: Frame) throws {
        try onFrame?(self, frame)

        if frame.isFragment {
            try receivedFragment(frame)
        } else {
            try routeMessage(for: frame.header.opCode, payload: frame.payload)
        }
    }

    private func routeMessage(for opCode: Frame.OpCode, payload: Bytes) throws {
        switch opCode {
        case .continuation:
            // fragment handled above
            throw Error.unexpectedFragmentFrame
        case .binary:
            try onBinary?(self, payload)
        case .text:
            let text = payload.makeString()
            try onText?(self, text)
        case let .nonControlExtension(nc):
            try onNonControlExtension?(self, nc, payload)
        case .connectionClose:
            try handleClose(payload: payload)
        case .ping:
            try onPing?(self, payload)
            try pong(payload)
        case .pong:
            try onPong?(self, payload)
        case let .controlExtension(ce):
            try onControlExtension?(self, ce, payload)
        }
    }

    private func receivedFragment(_ frame: Frame) throws {
        try aggregator?.append(fragment: frame)

        guard let (opCode, payload) = aggregator?.receiveCompleteMessage() else { return }
        try routeMessage(for: opCode, payload: payload)
    }

    private func handleClose(payload: Bytes) throws {
        /*
         If there is a body, the first two bytes of
         the body MUST be a 2-byte unsigned integer (in network byte order)
         representing a status code with value /code/ defined in Section 7.4.
         Following the 2-byte integer, the body MAY contain UTF-8-encoded data
         with value /reason/, the interpretation of which is not defined by
         this specification.  This data is not necessarily human readable but
         may be useful for debugging or passing information relevant to the
         script that opened the connection.  As the data is not guaranteed to
         be human readable, clients MUST NOT show it to end users.
         */
        var statusCode: UInt16?
        var statusCodeData: Bytes? = nil
        var reason: String? = nil
        if !payload.isEmpty {
            // if NOT empty, MUST be at least 2 byte UInt16 optionally followed by reason
            guard payload.count >= 2 else { throw FrameParserError.missingByte }
            let statusCodeBytes = payload[0...1].array
            statusCode = UInt16(bytes: statusCodeBytes)
            statusCodeData = statusCodeBytes
            // stringify remaining bytes -- if there are any
            reason = payload.dropFirst(2).makeString()
        }

        switch  state {
        case .open:
            // opponent requested close, we're responding

            /*
             If an endpoint receives a Close frame and did not previously send a
             Close frame, the endpoint MUST send a Close frame in response.  (When
             sending a Close frame in response, the endpoint typically echos the
             status code it received.

             First two bytes MUST be status code if they exist
             */
            try respondToClose(echo: statusCodeData ?? [])
            try completeCloseHandshake(statusCode: statusCode, reason: reason, cleanly: true)
        case .closing:
            // we requested close, opponent responded
            try completeCloseHandshake(statusCode: statusCode, reason: reason, cleanly: true)
        case .closed:
            break
            // TODO: Throw for application to catch
            // or pass logger

            // Log.info("Received close frame, already closed.")
        }
    }
}

// MARK: Close Handshake

extension WebSocket {
    /**
     Use this function to initiate a close with the client, a status code and reason may
     optionally be included

     The following formats are acceptable
     - statusCode only
     - statusCode and Reason

     The following formats are NOT acceptable
     - reason only

     The reason received on a status code must NOT be displayed to end user
     */
    public func close(statusCode: UInt16? = nil, reason: String? = nil) throws {
        guard state == .open else { return }
        state = .closing

        var payload: Bytes = []
        if let status = statusCode {
            payload += status.makeBytes()
        }
        if let reason = reason {
            payload += reason.makeBytes()
        }

        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .connectionClose,
            isMasked: mode.maskOutgoingMessages,
            payloadLength: UInt64(payload.count),
            maskingKey: mode.makeKey()
        )

        // Reason can _only_ exist if statusCode also exists
        // statusCode may exist _without_ a reason
        if statusCode == nil && reason != nil {
            throw Error.invalidPingFormat
        }

        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }

    // https://tools.ietf.org/html/rfc6455#section-5.5.1
    fileprivate func respondToClose(echo payload: Bytes) throws {
        // ensure haven't already sent
        guard state != .closed else { return }
        state = .closing

        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .connectionClose,
            isMasked: mode.maskOutgoingMessages,
            payloadLength: UInt64(payload.count),
            maskingKey: mode.makeKey()
        )
        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }

    fileprivate func completeCloseHandshake(statusCode: UInt16?, reason: String?, cleanly: Bool) throws {
        state = .closed
        try onClose?(self, statusCode, reason, cleanly)
    }
}
