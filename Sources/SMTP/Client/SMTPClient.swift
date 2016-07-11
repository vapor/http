import Base
import Engine

/*
     SMTP Makes use of multiple RFC specs

     ESMTP
     https://tools.ietf.org/html/rfc1869#section-4.3
     SMTP
     https://tools.ietf.org/html/rfc5321#section-4.5.3.2

     AUTH
     https://tools.ietf.org/html/rfc821#page-4
     GREAT UNOFFICIAL AUTH
     http://www.fehcom.de/qmail/smtpauth.html

     LEGACY - DO NOT SUPPORT
     https://tools.ietf.org/html/rfc821#page-4

     Timeouts
     https://tools.ietf.org/html/rfc5321#section-4.5.3.2
     
     
     Quickstart
     Specific sequences are:

     CONNECTION ESTABLISHMENT

     S: 220
     E: 554

     EHLO or HELO

     S: 250
     E: 504 (a conforming implementation could return this code only
     in fairly obscure cases), 550, 502 (permitted only with an old-
     style server that does not support EHLO)

     MAIL

     S: 250
     E: 552, 451, 452, 550, 553, 503, 455, 555

     RCPT

     S: 250, 251 (but see Section 3.4 for discussion of 251 and 551)
     E: 550, 551, 552, 553, 450, 451, 452, 503, 455, 555

     DATA

     I: 354 -> data -> S: 250

     E: 552, 554, 451, 452

     E: 450, 550 (rejections for policy reasons)

     E: 503, 554

     RSET

     S: 250

     VRFY

     S: 250, 251, 252
     E: 550, 551, 553, 502, 504

     EXPN

     S: 250, 252
     E: 550, 500, 502, 504

     HELP

     S: 211, 214
     E: 502, 504

     NOOP

     S: 250

     QUIT

     S: 221
*/


/**
    SMTPClient is designed to connect and transmit messages to SMTP Servers
*/
public final class SMTPClient<ClientStreamType: ClientStream>: ProgramStream {
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer

    internal let stream: Engine.Stream

    /**
         Connect the client to given SMTP Server
         
            try SMTPClient(host: "smtp.gmail.com", port: 465, securityLayer: .tls)
    */
    public init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.host = host
        self.port = port
        self.securityLayer  = securityLayer

        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
        let stream = try client.connect()
        self.stream = StreamBuffer(stream)
    }

    deinit {
        if !stream.closed {
            _ = try? stream.close()
        }
    }

    @discardableResult
    internal func negotiateSession(using credentials: SMTPCredentials, handler: @noescape (SMTPClient) throws -> Void) throws -> (code: Int, greeting: String) {
        try initializeSession(using: credentials)
        try handler(self)
        return try quit()
    }

    // MARK: Initialization

    private func initializeSession(using credentials: SMTPCredentials) throws {
        // TODO: Timeouts
        try acceptGreeting()
        // TODO: Should default to localhost?
        let (_, extensions) = try initiate(fromDomain: "localhost")
        // TODO: Should upgrade to TLS here if STARTTLS command exists BEFORE authorizing
        try authorize(extensions: extensions, using: credentials)
    }

    private func authorize(extensions: [EHLOExtension], using credentials: SMTPCredentials) throws {
        if let auth = extensions.authExtension {
            if auth.params.contains({ $0.equals(caseInsensitive: "LOGIN") }) {
                try authorize(method: .login, using: credentials)
            } else if auth.params.contains({ $0.equals(caseInsensitive: "PLAIN") }) {
                try authorize(method: .plain, using: credentials)
            } else {
                throw "no supported auth method"
            }
        } else {
            // no authorization required -- should we throw here?
            // I'm pretty sure classic SMTP is no login, aka, supah safe
            return
        }
    }

    /*
     https://tools.ietf.org/html/rfc5321#section-3.1

     3.1.  Session Initiation

     An SMTP session is initiated when a client opens a connection to a
     server and the server responds with an opening message.

     SMTP server implementations MAY include identification of their
     software and version information in the connection greeting reply
     after the 220 code, a practice that permits more efficient isolation
     and repair of any problems.  Implementations MAY make provision for
     SMTP servers to disable the software and version announcement where
     it causes security concerns.  While some systems also identify their
     contact point for mail problems, this is not a substitute for
     maintaining the required "postmaster" address (see Section 4).

     The SMTP protocol allows a server to formally reject a mail session
     while still allowing the initial connection as follows: a 554
     response MAY be given in the initial connection opening message
     instead of the 220.  A server taking this approach MUST still wait
     for the client to send a QUIT (see Section 4.1.1.10) before closing
     the connection and SHOULD respond to any intervening commands with
     "503 bad sequence of commands".  Since an attempt to make an SMTP
     connection to such a system is probably in error, a server returning
     a 554 response on connection opening SHOULD provide enough
     information in the reply text to facilitate debugging of the sending
     system.
     */
    private func acceptGreeting() throws {
        // After connect, client receives from server first.
        let (replyCode, greeting, isLast) = try acceptReplyLine()
        // initialization should be single line w/ 220
        if isLast && replyCode == 220 { return }
        else {
            // quit
            _ = try? quit()
            throw SMTPClientError.initializationFailed(code: replyCode, greeting: greeting)
        }
    }

    /*
     https://tools.ietf.org/html/rfc5321#section-3.2
     https://tools.ietf.org/html/rfc1869#section-4.3

     [WARNING] - sensitive code, make sure to consult rfc thoroughly
     */
    private func initiate(fromDomain: String = "localhost") throws -> (greeting: SMTPGreeting, extensions: [EHLOExtension]) {
        try transmit(line: "EHLO \(fromDomain)")
        var (code, replies) = try acceptReply()

        /*
         The 500 response indicates that the server SMTP does
         not implement thse extensions specified here.  The
         client would normally send a HELO command and proceed
         as specified in RFC 821.   See section 4.7 for
         additional discussion.
         */
        if code == 500 {
            try transmit(line: "HELO \(fromDomain)")
            (code, replies) = try acceptReply()
        }

        guard code == 250 else {
            /*
             In the case of any error response, the client SMTP should issue
             either the HELO or QUIT command.

             ^ we already tried HELO -- now we quit
             */
            _ = try? quit()
            throw "error initiating \(code)"
        }

        /*
         First line is header, subsequent lines are ehlo extensions
         */
        guard let greeting = try replies.first.flatMap(SMTPGreeting.init) else {
            throw "response should have at least one line -- even in SMTP original"
        }
        let extensions = try replies.dropFirst().map(EHLOExtension.init)
        return (greeting, extensions)
    }

    // MARK: Quit

    private func quit() throws -> (code: Int, greeting: String) {
        try transmit(line: "QUIT")
        let (code, reply, isLast) = try acceptReplyLine()
        guard isLast && code == 221 else { throw "failed to quit \(code) \(reply)" }
        return (code, reply)
    }
}
