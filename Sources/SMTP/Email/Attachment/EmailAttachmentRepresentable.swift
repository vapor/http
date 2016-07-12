/*
    Some objects, such as Images may want to conform to attachment representable for easier 
    interaction.
 
        email.attachments.append(someImage)
*/
public protocol EmailAttachmentRepresentable {
    /*
        The attachment that can be used to represent the underlying attachment
    */
    var emailAttachment: EmailAttachment { get }
}

extension EmailAttachment: EmailAttachmentRepresentable {
    public var emailAttachment: EmailAttachment {
        return self
    }
}
