public protocol EmailAttachmentRepresentable {
    var emailAttachment: EmailAttachment { get }
}

extension EmailAttachment: EmailAttachmentRepresentable {
    public var emailAttachment: EmailAttachment {
        return self
    }
}
