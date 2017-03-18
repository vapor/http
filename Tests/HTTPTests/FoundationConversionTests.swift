import XCTest
import URI
import Foundation

@testable import HTTP

class FoundationConversionTests: XCTestCase {
    static let allTests = [
        ("testUriToUrlConversion", testUriToUrlConversion),
        ("testUrlToUriConversion", testUrlToUriConversion),
        ("testRequestToUrlRequestConversion", testRequestToUrlRequestConversion),
        ("testUrlRequestToRequestConversion", testUrlRequestToRequestConversion),
        ("testFoundationClient", testFoundationClient),
    ]

    func testUriToUrlConversion() throws {
        let expectation = "https://google.com:443/search?foo=bar#frag"
        let uri = try URI(expectation)
        let url = try uri.makeFoundationURL()

        XCTAssertEqual(uri.scheme, url.scheme)
        XCTAssertEqual(uri.userInfo?.username, url.user)
        XCTAssertEqual(uri.userInfo?.info, url.password)
        XCTAssertEqual(uri.hostname, url.host)
        XCTAssertEqual(uri.port, url.port?.port)
        XCTAssertEqual(uri.query, url.query)
        XCTAssertEqual(uri.fragment, url.fragment)

        XCTAssertEqual(uri.description, expectation)
        XCTAssertEqual(url.absoluteString, expectation)
    }

    func testUrlToUriConversion() throws {
        let expectation = "https://google.com:443/search?foo=bar#frag"
        let url = URL(string: expectation)!
        let uri = url.makeURI()

        XCTAssertEqual(url.scheme, uri.scheme)
        XCTAssertEqual(url.user, uri.userInfo?.username)
        XCTAssertEqual(url.password, uri.userInfo?.info)
        XCTAssertEqual(url.host, uri.hostname)
        XCTAssertEqual(url.port, uri.port == nil ? nil : Int(uri.port!))
        XCTAssertEqual(url.query, uri.query)
        XCTAssertEqual(url.fragment, uri.fragment)

        XCTAssertEqual(url.absoluteString, expectation)
        XCTAssertEqual(uri.description, expectation)
    }

    func testRequestToUrlRequestConversion() throws {
        let body = Body("hello".makeBytes())
        let request = try Request(method: .get, uri: "http://google.com:80", headers: ["foo": "bar"], body: body)
        let urlRequest = try request.makeFoundationRequest()

        XCTAssertEqual(try request.uri.makeFoundationURL(), urlRequest.url)

        var requestHeaders = [String: String]()
        request.headers.forEach { key, val in requestHeaders[key.description] = val }
        XCTAssertEqual(requestHeaders, urlRequest.allHTTPHeaderFields ?? [:])

        let foundationBody = urlRequest.httpBody?.makeBytes()
        XCTAssertNotNil(foundationBody)
        let requestBody = request.body.bytes
        XCTAssertNotNil(requestBody)

        XCTAssertEqual(foundationBody ?? [], requestBody ?? [])
    }

    func testUrlRequestToRequestConversion() throws {
        let uri = try URI("http://google.com:80")
        let url = try uri.makeFoundationURL()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("bar", forHTTPHeaderField: "foo")
        urlRequest.httpBody = Data(bytes: "hello".makeBytes())

        let request = try urlRequest.makeRequest()

        XCTAssertEqual(try request.uri.makeFoundationURL(), urlRequest.url)

        let foundationBody = urlRequest.httpBody?.makeBytes()
        XCTAssertNotNil(foundationBody)
        let requestBody = request.body.bytes
        XCTAssertNotNil(requestBody)

        XCTAssertEqual(foundationBody ?? [], requestBody ?? [])
    }

    func testFoundationClient() throws {
        let response = try FoundationClient(scheme: "https", hostname: "httpbin.org", port: 443)
            .respond(to: Request(method: .get, uri: "https://httpbin.org/html"))

        let expectation = "Herman Melville - Moby-Dick"
        let contained = response.body.bytes?.makeString().contains(expectation) ?? false
        XCTAssertTrue(contained)

        var headersExpectation: [HeaderKey: String] = [:]
        headersExpectation["access-control-allow-credentials"] = "true"
        headersExpectation["Content-Type"] = "text/html; charset=utf-8"
        headersExpectation["Content-Length"] = "3741"
        headersExpectation["Server"] = "gunicorn/19.7.0"
        headersExpectation["Access-Control-Allow-Origin"] = "*"
        headersExpectation.forEach { key, expectedValue in
            let found = response.headers[key]
            XCTAssertEqual(found, expectedValue)
        }
    }
}
