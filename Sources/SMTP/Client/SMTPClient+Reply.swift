extension SMTPClient {
    /*
         The format for multiline replies requires that every line, except the
         last, begin with the reply code, followed immediately by a hyphen,
         "-" (also known as minus), followed by text.  The last line will
         begin with the reply code, followed immediately by <SP>, optionally
         some text, and <CRLF>.  As noted above, servers SHOULD send the <SP>
         if subsequent text is not sent, but clients MUST be prepared for it
         to be omitted.

         For example:

         250-First line
         250-Second line
         250-234 Text beginning with numbers
         250 The last line

         In a multiline reply, the reply code on each of the lines MUST be the
         same.  It is reasonable for the client to rely on this, so it can
         make processing decisions based on the code in any line, assuming
         that all others will be the same.  In a few cases, there is important
         data for the client in the reply "text".  The client will be able to
         identify these cases from the current context.
    */
    internal func acceptReply() throws -> (replyCode: Int, replies: [String]) {
        // first
        let (replyCode, initialReply, isLast) = try acceptReplyLine()
        var finished = isLast

        var replies: [String] = [initialReply]
        while !finished {
            let (code, reply, done) = try acceptReplyLine()
            guard code == replyCode else {
                throw SMTPClientError.invalidMultilineReply(expected: replyCode,
                                                            got: code,
                                                            replies: replies)
            }
            replies.append(reply)
            finished = done
        }

        return (replyCode, replies)
    }

    internal func acceptReplyLine() throws -> (replyCode: Int, reply: String, isLast: Bool) {
        let line = try stream.receiveLine()
        let replyCode = line.prefix(3).string.int ?? -1
        let token = line[safe: 3] // 0,1,2 == Status Code 3 is hyphen if should continue
        let reply = line.dropFirst(4).string
        // hyphen indicates continue, should send space, but doesn't have to
        // any NON-hyphen == last
        return (replyCode, reply, token != .hyphen)
    }
}

extension String {
    private var int: Int? {
        return Int(self)
    }
}
