import COpenSSL
import Foundation

extension WebSocket {
    // UUID defined here: https://tools.ietf.org/html/rfc6455#section-1.3
    private static let hashKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /*
         For this header field, the server has to take the value (as present
         in the header field, e.g., the base64-encoded [RFC4648] version minus
         any leading and trailing whitespace) and concatenate this with the
         Globally Unique Identifier (GUID, [RFC4122]) "258EAFA5-E914-47DA-
         95CA-C5AB0DC85B11" in string form, which is unlikely to be used by
         network endpoints that do not understand the WebSocket Protocol.  A
         SHA-1 hash (160 bits) [FIPS.180-3], base64-encoded (see Section 4 of
         [RFC4648]), of this concatenation is then returned in the server's
         handshake.

         Concretely, if as in the example above, the |Sec-WebSocket-Key|
         header field had the value "dGhlIHNhbXBsZSBub25jZQ==", the server
         would concatenate the string "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
         to form the string "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-
         C5AB0DC85B11".  The server would then take the SHA-1 hash of this,
         giving the value 0xb3 0x7a 0x4f 0x2c 0xc0 0x62 0x4f 0x16 0x90 0xf6
         0x46 0x06 0xcf 0x38 0x59 0x45 0xb2 0xbe 0xc4 0xea.  This value is
         then base64-encoded (see Section 4 of [RFC4648]), to give the value
         "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=".  This value would then be echoed in
         the |Sec-WebSocket-Accept| header field.
    */
    public static func exchange(requestKey: String) throws -> String {
        /*
         char data[] = "Hello, world!";
         size_t length = sizeof(data);

         unsigned char hash[SHA_DIGEST_LENGTH];
         SHA1(data, length, hash);
 */
        var data = requestKey.bytes.trimmed([.space]).array + hashKey.bytes
        var digestLength = Bytes(repeating: 0, count: SHA1_DIGEST_LENGTH)
        var result = SHA1(&data, data.count, &digestLength)
        /*
        let combination = requestKey.bytes.trimmed([.space]).string + hashKey
        print(combination)
        let result = try SHA1.hash(combination.bytes) 
        //let sha = try SHA1.hash(combination)
        print(result.hexString)
        print([0xb3, 0x7a, 0x4f, 0x2c, 0xc0, 0x62, 0x4f, 0x16, 0x90, 0xf6, 0x46, 0x06, 0xcf, 0x38, 0x59, 0x45, 0xb2, 0xbe, 0xc4, 0xea].hexString)

        let data = "hunter2"
        let hexSha1Data = try SHA1.hash(data.bytes).hexString // data.sha1().hexString
        print(hexSha1Data)
        //        XCTAssertEqual(hexSha1Data.lowercased(), "f3bbbd66a63d4bf1747940578ec3d0103530e21d")
        // print(sha.bytes.base64String)
        //let shaBytes = try SHA1.hash(combination).hexString.bytes.base64String

        // SHA1
        // let hashed = shaBytes.base64String
 */
        return "" //sha.base64String
    }
}
