//
//  URIModificationTests.swift
//  Engine
//
//  Created by Harlan Haskins on 9/25/16.
//
//

import XCTest
@testable import URI

class URIModificationTests: XCTestCase {
    static let allTests = [
        ("testAppendPathComponent", testAppendPathComponent),
        ("testRemovePathComponent", testRemovePathComponent),
        ("testRemovingPath", testRemovingPath),
        ("testLastPathComponent", testLastPathComponent),
    ]

    func testAppendPathComponent() {
        var uri = try! URI("https://vapor.github.io/documentation/")
        XCTAssertEqual(uri.path, "/documentation/")
        uri = uri.appendingPathComponent("foo")
        XCTAssertEqual(uri.path, "/documentation/foo")
        uri = uri.appendingPathComponent("bar")
        XCTAssertEqual(uri.path, "/documentation/foo/bar")
        uri = uri.appendingPathComponent("baz")
        XCTAssertEqual(uri.path, "/documentation/foo/bar/baz")
        uri = uri.appendingPathComponent("fizz", isDirectory: true)
        XCTAssertEqual(uri.path, "/documentation/foo/bar/baz/fizz/")
        uri = uri.appendingPathComponent("", isDirectory: true)
        XCTAssertEqual(uri.path, "/documentation/foo/bar/baz/fizz//")
        uri = uri.appendingPathComponent("", isDirectory: false)
        XCTAssertEqual(uri.path, "/documentation/foo/bar/baz/fizz//")
    }

    func testRemovePathComponent() {
        var uri = try! URI("https://vapor.github.io/documentation/foo/bar/baz")
        XCTAssertEqual(uri.path, "/documentation/foo/bar/baz")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.path, "/documentation/foo/bar")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.path, "/documentation/foo")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.path, "/documentation")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.path, "/")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.path, "/")
    }
    
    func testRemovingPath() {
        var uri = try! URI("https://vapor.github.io/documentation/foo/bar/baz")
        uri = uri.removingPath()
        XCTAssertEqual(uri.path, "/")
        uri = uri.removingPath()
        XCTAssertEqual(uri.path, "/")
    }
    
    func testLastPathComponent() {
        var uri = try! URI("https://vapor.github.io/documentation/foo/bar/baz")
        XCTAssertEqual(uri.lastPathComponent, "baz")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.lastPathComponent, "bar")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.lastPathComponent, "foo")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.lastPathComponent, "documentation")
        uri = uri.deletingLastPathComponent()
        XCTAssertEqual(uri.lastPathComponent, "")
        
    }
}
