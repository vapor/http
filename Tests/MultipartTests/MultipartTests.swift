import Multipart
import HTTP
import XCTest

class MultipartTests: XCTestCase {
    let named = """
    test123
    aijdisadi>SDASD<a|

    """
    
    let test = "eqw-dd-sa----123;1[234"
    
    let multinamed = """
    test123
    aijdisadi>dwekqie4u219034u129e0wque90qjsd90asffs


    SDASD<a|

    """
    
    var validMultipart: String {
        return """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"\r
        \r
        \(test)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="named"; filename=""\r
        \r
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        
        """
    }
    
    func testBasics() throws {
        let data = Data(validMultipart.utf8)
        
        XCTAssertEqual(Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8), try MultipartParser.boundary(for: data))
        
        let form = try MultipartParser(data: data, boundary: Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8)).parse()
        
        XCTAssertEqual(form.parts.count, 3)
        
        XCTAssertEqual(try form.getString(named: "test"), "eqw-dd-sa----123;1[234")
        XCTAssertEqual(try form.getFile(named: "named").data, Data(named.utf8))
        XCTAssertEqual(try form.getFile(named: "multinamed[]").data, Data(multinamed.utf8))

        let a = String(data: MultipartSerializer(form: form).serialize(), encoding: .ascii)
        XCTAssertEqual(a, string)
    }
    
    func testPartReading() throws {
        let data = Data(validMultipart.utf8)
        
        let form = try MultipartParser(data: data, boundary: MultipartParser.boundary(for: data)).parse()
        
        XCTAssertEqual(
            try form.getPart(named: "named").data,
            named.data(using: .utf8)
        )
        XCTAssertEqual(
            try form.getString(named: "test"),
            test
        )
    }

    func testMultifile() throws {
        let string = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"\r
        \r
        eqw-dd-sa----123;1[234\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        
        """
        
        let data = Data(string.utf8)
        
        let multipart = try MultipartParser(data: data, boundary: Array("----WebKitFormBoundaryPVOZifB9OqEwP2fn".utf8)).parse()
        
        let files = try multipart.getFiles(named: "multinamed[]")
        
        XCTAssertEqual(files.count, 2)
        let file = try multipart.getFile(named: "multinamed[]")
        XCTAssertEqual(file.data, Data(named.utf8))
        
        XCTAssertEqual(files.first?.data, Data(named.utf8))
        XCTAssertEqual(files.last?.data, Data(multinamed.utf8))
        
        XCTAssertEqual(MultipartSerializer(form: multipart).serialize(), data)
    }
    
    func testInvalidBoundaryState() {
        var invalid = validMultipart.data(using: .utf8)!
        invalid.removeFirst(1)
        
        XCTAssertThrowsError(
            try MultipartParser(
                data: invalid,
                boundary: try MultipartParser.boundary(for: invalid)
            ).parse()
        )
    }
    
    func testMissingBoundaryState() {
        var invalid = validMultipart.data(using: .utf8)!
        invalid.removeFirst(2)
        
        XCTAssertThrowsError(
            try MultipartParser(
                data: invalid,
                boundary: try MultipartParser.boundary(for: invalid)
                ).parse()
        )
    }
    
    func testInconsistentBoundary() {
        var invalid = validMultipart.data(using: .utf8)!
        invalid[3] = .underscore
        
        XCTAssertThrowsError(
            try MultipartParser(
                data: invalid,
                boundary: try MultipartParser.boundary(for: invalid)
                ).parse()
        )
    }
    
    func testMissingEndOfMultipart() {
        var invalid = validMultipart.data(using: .utf8)!
        invalid.removeLast(2)
        
        XCTAssertThrowsError(
            try MultipartParser(
                data: invalid,
                boundary: try MultipartParser.boundary(for: invalid)
            ).parse()
        )
    }
    
    func testMissingPart() throws {
        let data = self.validMultipart.data(using: .utf8)!
        
        let part = try MultipartParser(
            data: data,
            boundary: try MultipartParser.boundary(for: data)
        ).parse()
        
        XCTAssertThrowsError(try part.getString(named: "hello"))
    }
    
    func testMissingNewline() {
        let data = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn
        Content-Disposition: form-data; name="test"\r
        \r
        \(test)
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="named"; filename=""\r
        
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(
            try MultipartParser(
                data: data,
                boundary: try MultipartParser.boundary(for: data)
            ).parse()
        )
    }
    
    func testFormBoundary() {
        var string = "-hello\r\n"
        XCTAssertThrowsError(try MultipartParser.boundary(for: Data(string.utf8)))
        
        string = "--hello\r\n"
        XCTAssertNoThrow(try MultipartParser.boundary(for: Data(string.utf8)))
    }
    
    static let allTests = [
        ("testBasics", testBasics),
        ("testPartReading", testPartReading),
        ("testMultifile", testMultifile),
        ("testInvalidBoundaryState", testInvalidBoundaryState),
        ("testMissingBoundaryState", testMissingBoundaryState),
        ("testInconsistentBoundary", testInconsistentBoundary),
        ("testMissingEndOfMultipart", testMissingEndOfMultipart),
        ("testMissingPart", testMissingPart),
        ("testMissingNewline", testMissingNewline),
        ("testFormBoundary", testFormBoundary),
    ]
}
