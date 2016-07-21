import struct Core.Bytes

/*
    Attachments such as images and pdfs can be appended to emails using this object
*/
public struct EmailAttachment {
    /*
        The file name associated with the attachment, ie: `my-image.png`
    */
    public let filename: String

    /*
        The content type associated with the underlying data, for example:
     
            // image/png
            //  -- or --
            // application/pdf

    */
    public let contentType: String

    /*
        The body associated with the attachment in plain format. SPTClient will encode the
        bytes for transfer internally.
    */
    public let body: Bytes

    /*
        Initialize an attachment
    */
    public init(filename: String, contentType: String, body: Bytes) {
        self.filename = filename
        self.contentType = contentType
        self.body = body
    }
}
